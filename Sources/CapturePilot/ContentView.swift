import SwiftUI

struct ContentView: View {
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    
    var body: some View {
        Group {
            if isOnboardingComplete && permissionsManager.hasScreenRecordingPermission && permissionsManager.hasAccessibilityPermission {
                DashboardView()
            } else {
                OnboardingView(isOnboardingComplete: $isOnboardingComplete)
            }
        }
        .onAppear {
            permissionsManager.checkPermissions()
        }
    }
}
