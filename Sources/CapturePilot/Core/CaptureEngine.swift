import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

class CaptureEngine: ObservableObject {
    static let shared = CaptureEngine()
    
    @Published var isCapturing = false
    @Published var lastCapturedImage: NSImage?
    @Published var captureCount = 0
    
    private var timer: Timer?
    private var sessionFolder: URL?
    
    @Published var currentSessionFolder: URL?
    
    // Configuration
    @Published var interval: TimeInterval = 1.0 {
        didSet {
            // Round to nearest whole number
            let rounded = round(interval)
            if rounded != interval {
                interval = max(1.0, rounded)
            }
        }
    }
    @Published var captureRect: CGRect? = nil
    @Published var selectedAppPID: pid_t? = nil
    @Published var automationKey: AutomationKey = .none
    @Published var hideWindowOnCapture: Bool = true
    var saveDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/CapturePilot")
    
    private let automationEngine = AutomationEngine()
    private let windowManager = WindowManager.shared
    private let menuBarManager = MenuBarManager.shared
    
    private init() {
        createSaveDirectory()
        setupMenuBar()
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
        
        isCapturing = true
        captureCount = 0
        
        // Initial capture
        capture()
        performAutomation()
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.capture()
            self?.performAutomation()
        }
    }
    
    func stopCapture() {
        isCapturing = false
        timer?.invalidate()
        timer = nil
        
        // Hide menu bar and show window
        menuBarManager.updateCapturingState(false)
        menuBarManager.hideMenuBar()
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
            self.captureCount += 1
            self.menuBarManager.updateCaptureCount(self.captureCount)
        }
        
        // Save to disk
        saveImage(finalImage)
    }
    
    private func saveImage(_ image: CGImage) {
        guard let sessionFolder = sessionFolder else { return }
        
        let filename = "Capture_\(String(format: "%04d", captureCount)).png"
        let fileURL = sessionFolder.appendingPathComponent(filename)
        
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else { return }
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("Failed to save image: \(error)")
        }
    }
}
