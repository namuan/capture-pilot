import SwiftUI

struct ContentView: View {
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    
    var body: some View {
        Group {
            if isOnboardingComplete && PermissionsManager.shared.hasScreenRecordingPermission && PermissionsManager.shared.hasAccessibilityPermission {
                DashboardView()
            } else {
                OnboardingView(isOnboardingComplete: $isOnboardingComplete)
            }
        }
        .onAppear {
            PermissionsManager.shared.checkPermissions()
        }
    }
}
