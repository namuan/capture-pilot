import SwiftUI
import AppKit

@main
struct CapturePilotApp: App {
    let persistenceController = PersistenceController.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the main window reference
        if let window = NSApplication.shared.windows.first {
            WindowManager.shared.setMainWindow(window)
        }
    }
}
