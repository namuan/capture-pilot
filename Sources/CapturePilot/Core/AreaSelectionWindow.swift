import AppKit
import SwiftUI

class AreaSelectionWindow: NSObject {
    static let shared = AreaSelectionWindow()
    
    private var window: NSWindow?
    private var completionHandler: ((CGRect?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func selectArea(completion: @escaping (CGRect?) -> Void) {
        completionHandler = completion
        
        DispatchQueue.main.async { [weak self] in
            self?.showSelectionWindow()
        }
    }
    
    private func showSelectionWindow() {
        guard let screen = NSScreen.main else {
            completeWithResult(nil)
            return
        }
        
        let screenFrame = screen.frame
        
        let window = NSWindow(
            contentRect: screenFrame,
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
        
        let selectionView = AreaSelectionNSView(frame: NSRect(origin: .zero, size: screenFrame.size))
        selectionView.onCancel = { [weak self] in
            self?.completeWithResult(nil)
        }
        selectionView.onComplete = { [weak self] rect in
            self?.completeWithResult(rect)
        }
        
        window.contentView = selectionView
        self.window = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func completeWithResult(_ rect: CGRect?) {
        let handler = completionHandler
        completionHandler = nil
        
        guard let window = window else { return }
        self.window = nil
        
        window.orderOut(nil)
        
        DispatchQueue.main.async {
            if let rect = rect {
                if let screen = NSScreen.main {
                    let screenFrame = screen.frame
                    let convertedRect = CGRect(
                        x: rect.origin.x,
                        y: screenFrame.height - rect.origin.y - rect.height,
                        width: rect.width,
                        height: rect.height
                    )
                    handler?(convertedRect)
                } else {
                    handler?(rect)
                }
            } else {
                handler?(nil)
            }
        }
    }
}

private class AreaSelectionNSView: NSView {
    var onCancel: (() -> Void)?
    var onComplete: ((CGRect) -> Void)?
    
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
        super.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
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
            onComplete?(rect)
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
    
    private func resetSelection() {
        startPoint = nil
        currentPoint = nil
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        if let rect = selectionRect {
            NSColor.black.withAlphaComponent(0.3).setFill()
            NSBezierPath(rect: bounds).fill()
            
            NSColor.clear.setFill()
            NSBezierPath(rect: rect).fill()
            
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2
            NSColor.controlAccentColor.setStroke()
            borderPath.stroke()
            
            drawCornerHandles(in: rect)
            
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
        
        drawInstructions()
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
            
            NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2).fill()
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
    
    private func drawInstructions() {
        let instruction = "Drag to select area • Press ESC to cancel" as NSString
        
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
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6)
        bgPath.fill()
        
        let textRect = NSRect(
            x: bgRect.origin.x + padding,
            y: bgRect.origin.y + padding / 2,
            width: textSize.width,
            height: textSize.height
        )
        instruction.draw(in: textRect, withAttributes: attrs)
    }
}
