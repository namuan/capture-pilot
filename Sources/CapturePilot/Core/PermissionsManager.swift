import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var hasScreenRecordingPermission = false
    @Published var hasAccessibilityPermission = false
    
    init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        // Open System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
