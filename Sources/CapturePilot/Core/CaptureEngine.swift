import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers
import CryptoKit

class CaptureEngine: ObservableObject {
    static let shared = CaptureEngine()

    private struct PixelSnapshot {
        let width: Int
        let height: Int
        let data: Data
    }
    
    @Published var isCapturing = false
    @Published var lastCapturedImage: NSImage?
    @Published var captureCount = 0
    
    private var timer: Timer?
    private var sessionFolder: URL?
    private var lastSavedCaptureHash: Data?
    private var lastSavedPixelSnapshot: PixelSnapshot?
    private let nearIdenticalChannelTolerance = 8
    
    @Published var currentSessionFolder: URL?
    
    // Configuration
    // Default interval is 10 seconds. Enforce whole-second values and clamp to 1..500.
    @Published var interval: TimeInterval = 10.0 {
        didSet {
            // Round to nearest whole number and clamp to allowed range
            let rounded = round(interval)
            let clamped = min(max(1.0, rounded), 500.0)
            if clamped != interval {
                interval = clamped
            }
        }
    }
    @Published var captureRect: CGRect? = nil
    @Published var selectedAppPID: pid_t? = nil
    @Published var automationKey: AutomationKey = .none
    @Published var hideWindowOnCapture: Bool = true
    @Published var nearIdenticalModeEnabled = true
    @Published var nearIdenticalPixelThreshold: Double = 0.003 {
        didSet {
            let clamped = min(max(0.0, nearIdenticalPixelThreshold), 0.10)
            if clamped != nearIdenticalPixelThreshold {
                nearIdenticalPixelThreshold = clamped
            }
        }
    }
    var saveDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/CapturePilot")
    
    var onCaptureStopped: (() -> Void)?
    
    private let automationEngine = AutomationEngine()
    private let windowManager = WindowManager.shared
    private let menuBarManager = MenuBarManager.shared
    private var screenLockObserver: NSObjectProtocol?
    private var screenUnlockObserver: NSObjectProtocol?
    private var machineWillSleepObserver: NSObjectProtocol?
    private var machineDidWakeObserver: NSObjectProtocol?
    private var isScreenLocked = false
    private var isMachineAsleep = false
    
    private init() {
        createSaveDirectory()
        setupMenuBar()
        setupSystemStateObservers()
    }

    deinit {
        if let observer = screenLockObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if let observer = screenUnlockObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if let observer = machineWillSleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = machineDidWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    private func setupMenuBar() {
        menuBarManager.configure(
            stopCapture: { [weak self] in
                self?.stopCapture()
            },
            showWindow: {
                WindowManager.shared.showWindow()
            }
        )
    }

    private func setupSystemStateObservers() {
        let distributedCenter = DistributedNotificationCenter.default()
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        screenLockObserver = distributedCenter.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isScreenLocked = true
            self?.updateCaptureStateForSystemEvents()
        }

        screenUnlockObserver = distributedCenter.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isScreenLocked = false
            self?.updateCaptureStateForSystemEvents()
        }

        machineWillSleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isMachineAsleep = true
            self?.updateCaptureStateForSystemEvents()
        }

        machineDidWakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isMachineAsleep = false
            self?.updateCaptureStateForSystemEvents()
        }
    }

    private func updateCaptureStateForSystemEvents() {
        guard isCapturing else { return }

        if isScreenLocked || isMachineAsleep {
            pauseCaptureTimer()
            return
        }

        resumeCaptureTimerIfNeeded()
    }

    private func pauseCaptureTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resumeCaptureTimerIfNeeded() {
        guard timer == nil else { return }

        capture()
        performAutomation()
        startCaptureTimer()
    }

    private func startCaptureTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.capture()
            self?.performAutomation()
        }
    }
    
    private func createSaveDirectory() {
        if !FileManager.default.fileExists(atPath: saveDirectory.path) {
            try? FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
        }
    }
    
    func startCapture() {
        guard !isCapturing else { return }
        
        // Hide window if enabled
        if hideWindowOnCapture {
            windowManager.hideWindow()
        }
        
        // Show menu bar
        menuBarManager.showMenuBar()
        menuBarManager.updateCapturingState(true)
        
        // Create session folder
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let sessionName = "Session_\(dateFormatter.string(from: Date()))"
        let sessionURL = saveDirectory.appendingPathComponent(sessionName)
        try? FileManager.default.createDirectory(at: sessionURL, withIntermediateDirectories: true)
        
        self.currentSessionFolder = sessionURL
        self.sessionFolder = sessionURL
        self.lastSavedCaptureHash = nil
        self.lastSavedPixelSnapshot = nil
        
        isCapturing = true
        captureCount = 0
        
        // Initial capture
        capture()
        performAutomation()
        
        // Start timer
        startCaptureTimer()
    }
    
    func stopCapture() {
        isCapturing = false
        timer?.invalidate()
        timer = nil
        lastSavedCaptureHash = nil
        lastSavedPixelSnapshot = nil
        
         // Save session to Core Data
        if let folder = currentSessionFolder {
            let viewContext = PersistenceController.shared.container.viewContext
            let newSession = CaptureSession(context: viewContext)
            newSession.path = folder.path
            try? viewContext.save()
        }
        
        // Hide menu bar and show window
        menuBarManager.updateCapturingState(false)
        menuBarManager.hideMenuBar()
        
        // Call the callback to dismiss the view
        onCaptureStopped?()
        
        windowManager.showWindow()
    }
    
    private func performAutomation() {
        guard automationKey != .none else { return }
        // Delay automation slightly to ensure capture is done? 
        // Synchronous capture usually blocks until we have the image, but saving is async-ish.
        // CGWindowListCreateImage is synchronous.
        // So we can trigger keypress immediately.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isCapturing else { return }
            self.automationEngine.simulateKeyPress(key: self.automationKey)
        }
    }
    
    private func capture() {
        var cgImage: CGImage?
        
        if let pid = selectedAppPID {
            // Capture specific app windows
            // We need to find windows for this PID
            if let windowInfoList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
                // Find the main window(s) for the app
                let appWindows = windowInfoList.filter {
                    ($0[kCGWindowOwnerPID as String] as? pid_t) == pid
                }
                
                // For simplicity, we can try to capture the "main" window or the union of all
                // But CGWindowListCreateImage with .optionIncludingWindow requires a WindowID.
                // Let's try to capture the largest window or the first one that looks like a main window
                if let mainWin = appWindows.first, let windowID = mainWin[kCGWindowNumber as String] as? CGWindowID {
                    cgImage = CGWindowListCreateImage(
                        .null,
                        .optionIncludingWindow,
                        windowID,
                        .bestResolution
                    )
                }
            }
        } else {
            // Fullscreen or Rect
            cgImage = CGWindowListCreateImage(
                captureRect ?? CGRect.infinite,
                .optionOnScreenOnly,
                kCGNullWindowID,
                .bestResolution
            )
        }
        
        guard let finalImage = cgImage else { return }
        
        // Update UI
        let nsImage = NSImage(cgImage: finalImage, size: NSSize(width: finalImage.width, height: finalImage.height))
        DispatchQueue.main.async {
            self.lastCapturedImage = nsImage
        }
        
        // Save to disk
        if saveImage(finalImage) {
            DispatchQueue.main.async {
                self.captureCount += 1
                self.menuBarManager.updateCaptureCount(self.captureCount)
            }
        }
    }
    
    private func saveImage(_ image: CGImage) -> Bool {
        guard let sessionFolder = sessionFolder else { return false }
        
        let filename = "Capture_\(String(format: "%04d", captureCount)).png"
        let fileURL = sessionFolder.appendingPathComponent(filename)
        
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else { return false }

        let currentHash = Data(SHA256.hash(data: data))
        if lastSavedCaptureHash == currentHash {
            return false
        }

        let currentPixelSnapshot = nearIdenticalModeEnabled ? makePixelSnapshot(from: image) : nil
        if nearIdenticalModeEnabled,
           let currentPixelSnapshot,
           let lastSavedPixelSnapshot,
           isNearIdentical(currentPixelSnapshot, comparedTo: lastSavedPixelSnapshot) {
            return false
        }
        
        do {
            try data.write(to: fileURL)
            lastSavedCaptureHash = currentHash
            lastSavedPixelSnapshot = currentPixelSnapshot
            return true
        } catch {
            print("Failed to save image: \(error)")
            return false
        }
    }

    private func makePixelSnapshot(from image: CGImage) -> PixelSnapshot? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow
        var rawData = Data(count: totalBytes)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let didDraw = rawData.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard didDraw else { return nil }
        return PixelSnapshot(width: width, height: height, data: rawData)
    }

    private func isNearIdentical(_ current: PixelSnapshot, comparedTo previous: PixelSnapshot) -> Bool {
        guard current.width == previous.width, current.height == previous.height else { return false }

        let pixelCount = current.width * current.height
        guard pixelCount > 0 else { return false }

        let maxDifferentPixels = Int(Double(pixelCount) * nearIdenticalPixelThreshold)
        var differentPixels = 0

        previous.data.withUnsafeBytes { previousBytes in
            current.data.withUnsafeBytes { currentBytes in
                let previousPixels = previousBytes.bindMemory(to: UInt8.self)
                let currentPixels = currentBytes.bindMemory(to: UInt8.self)

                var offset = 0
                for _ in 0..<pixelCount {
                    let redDiff = abs(Int(previousPixels[offset]) - Int(currentPixels[offset]))
                    let greenDiff = abs(Int(previousPixels[offset + 1]) - Int(currentPixels[offset + 1]))
                    let blueDiff = abs(Int(previousPixels[offset + 2]) - Int(currentPixels[offset + 2]))
                    let alphaDiff = abs(Int(previousPixels[offset + 3]) - Int(currentPixels[offset + 3]))

                    if max(redDiff, max(greenDiff, max(blueDiff, alphaDiff))) > nearIdenticalChannelTolerance {
                        differentPixels += 1
                        if differentPixels > maxDifferentPixels {
                            break
                        }
                    }

                    offset += 4
                }
            }
        }

        return differentPixels <= maxDifferentPixels
    }
}
