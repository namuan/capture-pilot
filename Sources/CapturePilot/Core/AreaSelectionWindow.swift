import AppKit
import SwiftUI

class AreaSelectionWindow: NSObject {
    static let shared = AreaSelectionWindow()
    
    private var windows: [NSWindow] = []
    private var completionHandler: ((CGRect?) -> Void)?
    private var isCompleted = false
    
    private override init() {
        super.init()
    }
    
    func selectArea(completion: @escaping (CGRect?) -> Void) {
        completionHandler = completion
        isCompleted = false
        
        DispatchQueue.main.async { [weak self] in
            self?.showSelectionWindows()
        }
    }
    
    private func showSelectionWindows() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            completeWithResult(nil)
            return
        }
        
        for screen in screens {
            let screenFrame = screen.frame
            
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: screenFrame.size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.hidesOnDeactivate = false
            window.acceptsMouseMovedEvents = true
            
            window.setFrameOrigin(screenFrame.origin)
            
            let screenIndex = screens.firstIndex(of: screen) ?? 0
            let totalScreens = screens.count
            
            let selectionView = SingleScreenSelectionView(
                frame: NSRect(origin: .zero, size: screenFrame.size),
                screen: screen,
                screenIndex: screenIndex,
                totalScreens: totalScreens
            )
            selectionView.onCancel = { [weak self] in
                self?.completeWithResult(nil)
            }
            selectionView.onComplete = { [weak self] rect in
                self?.completeWithResult(rect)
            }
            
            window.contentView = selectionView
            windows.append(window)
            
            window.makeKeyAndOrderFront(nil)
        }
        
        if let firstWindow = windows.first {
            firstWindow.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func completeWithResult(_ rect: CGRect?) {
        guard !isCompleted else { return }
        isCompleted = true
        
        let handler = completionHandler
        completionHandler = nil
        
        let windowsToClose = windows
        windows = []
        
        for window in windowsToClose {
            window.orderOut(nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            handler?(rect)
        }
    }
}

private class SingleScreenSelectionView: NSView {
    var onCancel: (() -> Void)?
    var onComplete: ((CGRect) -> Void)?
    
    private let screen: NSScreen
    private let screenIndex: Int
    private let totalScreens: Int
    
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false
    private var trackingArea: NSTrackingArea?
    
    init(frame frameRect: NSRect, screen: NSScreen, screenIndex: Int, totalScreens: Int) {
        self.screen = screen
        self.screenIndex = screenIndex
        self.totalScreens = totalScreens
        super.init(frame: frameRect)
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        let options: NSTrackingArea.Options = [
            .inVisibleRect,
            .activeAlways,
            .enabledDuringMouseDrag,
            .mouseMoved
        ]
        
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
        super.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        startPoint = localPoint
        currentPoint = localPoint
        isDragging = true
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        
        if let rect = selectionRect, rect.width > 10 && rect.height > 10 {
            let globalRect = convertToGlobalCoordinates(rect)
            onComplete?(globalRect)
        } else {
            resetSelection()
        }
    }
    
    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
    
    private func convertToGlobalCoordinates(_ localRect: CGRect) -> CGRect {
        let screenFrame = screen.frame
        return CGRect(
            x: screenFrame.origin.x + localRect.origin.x,
            y: screenFrame.origin.y + localRect.origin.y,
            width: localRect.width,
            height: localRect.height
        )
    }
    
    private func resetSelection() {
        startPoint = nil
        currentPoint = nil
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        drawScreenIndicator()
        
        if let rect = selectionRect {
            NSColor.clear.setFill()
            NSBezierPath(rect: rect).fill()
            
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2
            NSColor.controlAccentColor.setStroke()
            borderPath.stroke()
            
            drawCornerHandles(in: rect)
            drawSizeLabel(in: rect)
        }
        
        drawInstructions()
    }
    
    private func drawScreenIndicator() {
        let screenNumber = screenIndex + 1
        let indicatorSize: CGFloat = 40
        let indicatorRect = NSRect(
            x: bounds.midX - indicatorSize / 2,
            y: bounds.midY - indicatorSize / 2,
            width: indicatorSize,
            height: indicatorSize
        )
        
        NSColor.black.withAlphaComponent(0.5).setFill()
        NSBezierPath(roundedRect: indicatorRect.insetBy(dx: -4, dy: -4), xRadius: 8, yRadius: 8).fill()
        
        let numberText = "\(screenNumber)" as NSString
        let textStyle = NSMutableParagraphStyle()
        textStyle.alignment = .center
        
        let textRect = NSRect(
            x: indicatorRect.origin.x,
            y: indicatorRect.origin.y + (indicatorRect.height - 28) / 2,
            width: indicatorRect.width,
            height: 28
        )
        
        numberText.draw(in: textRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.4),
            .paragraphStyle: textStyle
        ])
    }
    
    private func drawCornerHandles(in rect: CGRect) {
        let handleSize: CGFloat = 8
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        
        for corner in corners {
            let handleRect = NSRect(
                x: corner.x - handleSize / 2,
                y: corner.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            
            NSColor.white.setFill()
            NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2).fill()
            
            NSColor.controlAccentColor.setStroke()
            let borderRect = NSRect(
                x: handleRect.origin.x - 0.5,
                y: handleRect.origin.y - 0.5,
                width: handleRect.width + 1,
                height: handleRect.height + 1
            )
            NSBezierPath(roundedRect: borderRect, xRadius: 2, yRadius: 2).stroke()
        }
    }
    
    private func drawSizeLabel(in rect: CGRect) {
        let sizeText = "\(Int(rect.width)) × \(Int(rect.height))" as NSString
        let textSize = sizeText.size(withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ])
        
        let textBackgroundRect = NSRect(
            x: rect.midX - textSize.width / 2 - 8,
            y: rect.maxY + 8,
            width: textSize.width + 16,
            height: textSize.height + 8
        )
        
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: textBackgroundRect, xRadius: 4, yRadius: 4).fill()
        
        let textRect = NSRect(
            x: textBackgroundRect.origin.x + 8,
            y: textBackgroundRect.origin.y + 4,
            width: textSize.width,
            height: textSize.height
        )
        sizeText.draw(in: textRect, withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ])
    }
    
    private func drawInstructions() {
        let monitorText = totalScreens > 1 ? "Multiple displays (\(screenIndex + 1)/\(totalScreens)) • " : ""
        let instruction = "\(monitorText)Drag to select • ESC to cancel" as NSString
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let textSize = instruction.size(withAttributes: attrs)
        let padding: CGFloat = 12
        
        let bgRect = NSRect(
            x: bounds.midX - textSize.width / 2 - padding,
            y: bounds.height - 50,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )
        
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6).fill()
        
        let textRect = NSRect(
            x: bgRect.origin.x + padding,
            y: bgRect.origin.y + padding / 2,
            width: textSize.width,
            height: textSize.height
        )
        instruction.draw(in: textRect, withAttributes: attrs)
    }
}
