import AppKit
import SwiftUI

class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()
    
    @Published var isCapturing: Bool = false
    @Published var captureCount: Int = 0
    
    private var statusItem: NSStatusItem?
    private var stopCaptureHandler: (() -> Void)?
    private var showWindowHandler: (() -> Void)?
    
    private init() {}
    
    func configure(stopCapture: @escaping () -> Void, showWindow: @escaping () -> Void) {
        self.stopCaptureHandler = stopCapture
        self.showWindowHandler = showWindow
    }
    
    func showMenuBar() {
        DispatchQueue.main.async { [weak self] in
            guard self?.statusItem == nil else { return }
            
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Capturing")
                button.title = " 0"
            }
            
            let menu = NSMenu()
            
            let stopItem = NSMenuItem(title: "Stop Capture", action: #selector(self?.stopCapture), keyEquivalent: "")
            stopItem.target = self
            menu.addItem(stopItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let showWindowItem = NSMenuItem(title: "Show Window", action: #selector(self?.showWindow), keyEquivalent: "")
            showWindowItem.target = self
            menu.addItem(showWindowItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let quitItem = NSMenuItem(title: "Quit CapturePilot", action: #selector(self?.quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            
            statusItem.menu = menu
            
            self?.statusItem = statusItem
        }
    }
    
    func hideMenuBar() {
        DispatchQueue.main.async { [weak self] in
            guard let statusItem = self?.statusItem else { return }
            NSStatusBar.system.removeStatusItem(statusItem)
            self?.statusItem = nil
        }
    }
    
    func updateCaptureCount(_ count: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.captureCount = count
            if let button = self?.statusItem?.button {
                button.title = " \(count)"
            }
        }
    }
    
    func updateCapturingState(_ capturing: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = capturing
            if let button = self?.statusItem?.button {
                if capturing {
                    button.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Capturing")
                } else {
                    button.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Not capturing")
                }
            }
        }
    }
    
    @objc private func stopCapture() {
        stopCaptureHandler?()
    }
    
    @objc private func showWindow() {
        showWindowHandler?()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
