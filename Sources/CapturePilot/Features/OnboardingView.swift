import SwiftUI

struct OnboardingView: View {
    @StateObject private var permissionsManager = PermissionsManager()
    @Binding var isOnboardingComplete: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)
            
            Text("Permissions Required")
                .font(.largeTitle)
                .bold()
            
            Text("CapturePilot needs access to your screen to take screenshots and accessibility features to automate workflow.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 20) {
                PermissionRow(
                    title: "Screen Recording",
                    description: "Required to capture screen content.",
                    isGranted: permissionsManager.hasScreenRecordingPermission,
                    action: permissionsManager.requestScreenRecordingPermission
                )
                
                PermissionRow(
                    title: "Accessibility",
                    description: "Required to simulate keystrokes.",
                    isGranted: permissionsManager.hasAccessibilityPermission,
                    action: permissionsManager.requestAccessibilityPermission
                )
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
            
            HStack {
                Button("Check Again") {
                    permissionsManager.checkPermissions()
                }
                .buttonStyle(.plain)
                .padding()
                
                Button("Continue") {
                    if permissionsManager.hasScreenRecordingPermission && permissionsManager.hasAccessibilityPermission {
                        isOnboardingComplete = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!permissionsManager.hasScreenRecordingPermission || !permissionsManager.hasAccessibilityPermission)
            }
        }
        .padding()
        .frame(width: 500, height: 600)
        .onAppear {
            permissionsManager.checkPermissions()
        }
        // Poll for changes when window is active
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionsManager.checkPermissions()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isGranted ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !isGranted {
                Button("Grant") {
                    action()
                }
            }
        }
    }
}
