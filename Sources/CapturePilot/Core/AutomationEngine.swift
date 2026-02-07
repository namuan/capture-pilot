import Foundation
import CoreGraphics

enum AutomationKey: String, CaseIterable, Identifiable {
    case rightArrow = "Right Arrow"
    case leftArrow = "Left Arrow"
    case space = "Space"
    case pageDown = "Page Down"
    case none = "None"
    
    var id: String { self.rawValue }
    
    var keyCode: CGKeyCode? {
        switch self {
        case .rightArrow: return 124
        case .leftArrow: return 123
        case .space: return 49
        case .pageDown: return 121
        case .none: return nil
        }
    }
}

class AutomationEngine {
    func simulateKeyPress(key: AutomationKey) {
        guard let keyCode = key.keyCode else { return }
        
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        
        keyDown?.post(tap: .cghidEventTap)
        // Check if we need a tiny delay between down and up, usually not for simple taps but safe to post sequentially
        keyUp?.post(tap: .cghidEventTap)
    }
}
