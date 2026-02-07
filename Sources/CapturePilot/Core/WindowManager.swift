import AppKit
import SwiftUI

class WindowManager {
    static let shared = WindowManager()
    
    private var mainWindow: NSWindow?
    
    func setMainWindow(_ window: NSWindow?) {
        self.mainWindow = window
    }
    
    func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.mainWindow?.orderOut(nil)
            NSApp.hide(nil)
        }
    }
    
    func showWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.mainWindow else { return }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func isWindowVisible() -> Bool {
        return mainWindow?.isVisible ?? false
    }
}
