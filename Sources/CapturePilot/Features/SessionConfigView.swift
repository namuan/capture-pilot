import SwiftUI

struct SessionConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var captureEngine = CaptureEngine()
    
    var body: some View {
        VStack(spacing: 0) {
            if captureEngine.isCapturing {
                CapturingView(captureEngine: captureEngine, dismiss: dismiss)
            } else {
                ConfigurationView(captureEngine: captureEngine)
            }
        }
        .frame(width: 650, height: 550)
    }
}

// MARK: - Capturing View
private struct CapturingView: View {
    @ObservedObject var captureEngine: CaptureEngine
    let dismiss: DismissAction
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if let image = captureEngine.lastCapturedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 300)
                    .background(Color(NSColor.controlBackgroundColor))
                    .border(Color.secondary.opacity(0.3), width: 1)
                    .shadow(radius: 2)
            } else {
                ProgressView("Waiting for first capture...")
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
            }
            
            Text("\(captureEngine.captureCount) captures")
                .font(.title2)
                .fontWeight(.medium)
                .padding(.top, 8)
            
            Spacer()
            
            Button("Stop Session") {
                captureEngine.stopCapture()
                // Save session to Core Data and dismiss
                if let folder = captureEngine.currentSessionFolder {
                    let viewContext = PersistenceController.shared.container.viewContext
                    let newSession = CaptureSession(context: viewContext)
                    newSession.id = UUID()
                    newSession.date = Date()
                    newSession.path = folder.path
                    
                    try? viewContext.save()
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Configuration View
private struct ConfigurationView: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                CaptureSettingsSection(captureEngine: captureEngine)
                TargetSourceSection(captureEngine: captureEngine)
                OutputSection(captureEngine: captureEngine)
            }
            
            StartCaptureButton(captureEngine: captureEngine)
        }
    }
}

// MARK: - Capture Settings Section
private struct CaptureSettingsSection: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        Section {
            HStack(alignment: .center, spacing: 16) {
                Text("Interval:")
                    .frame(width: 90, alignment: .trailing)
                HStack(spacing: 12) {
                    Slider(value: $captureEngine.interval, in: 0.5...60, step: 0.5)
                        .frame(minWidth: 200)
                    Text(String(format: "%.1fs", captureEngine.interval))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
            .padding(.vertical, 4)
            
            HStack(alignment: .center, spacing: 16) {
                Text("Auto-Key:")
                    .frame(width: 90, alignment: .trailing)
                Picker("Auto-Key", selection: $captureEngine.automationKey) {
                    ForEach(AutomationKey.allCases) { key in
                        Text(key.rawValue).tag(key)
                    }
                }
                .labelsHidden()
                .frame(width: 200, alignment: .leading)
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("Capture Settings")
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Target Source Section
private struct TargetSourceSection: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    private var captureType: String {
        if captureEngine.captureRect == nil && captureEngine.selectedAppPID == nil {
            return "Fullscreen"
        } else if captureEngine.selectedAppPID != nil {
            return "App"
        } else {
            return "Custom"
        }
    }
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                captureTypePicker
                
                if captureEngine.selectedAppPID != nil {
                    appPicker
                } else if captureEngine.captureRect != nil {
                    CustomAreaEditor(captureEngine: captureEngine)
                }
            }
        } header: {
            Text("Target Source")
        }
        .padding(.bottom, 8)
    }
    
    private var captureTypePicker: some View {
        Picker("Type:", selection: Binding(
            get: { captureType },
            set: { newValue in
                switch newValue {
                case "Fullscreen":
                    captureEngine.captureRect = nil
                    captureEngine.selectedAppPID = nil
                case "App":
                    captureEngine.captureRect = nil
                    if captureEngine.selectedAppPID == nil {
                        if let firstApp = NSWorkspace.shared.runningApplications.first(where: { $0.activationPolicy == .regular }) {
                            captureEngine.selectedAppPID = firstApp.processIdentifier
                        }
                    }
                case "Custom":
                    captureEngine.selectedAppPID = nil
                    if captureEngine.captureRect == nil {
                        captureEngine.captureRect = CGRect(x: 100, y: 100, width: 800, height: 600)
                    }
                default:
                    break
                }
            }
        )) {
            Text("Fullscreen").tag("Fullscreen")
            Text("Application").tag("App")
            Text("Custom Area").tag("Custom")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
    
    private var appPicker: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Application:")
                .frame(width: 90, alignment: .trailing)
            Picker("Application", selection: $captureEngine.selectedAppPID) {
                ForEach(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }, id: \.processIdentifier) { app in
                    Text(app.localizedName ?? "Unknown").tag(Optional(app.processIdentifier))
                }
            }
            .labelsHidden()
            .frame(width: 200, alignment: .leading)
            Spacer()
        }
        .padding(.top, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Area Editor
private struct CustomAreaEditor: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        if let rect = captureEngine.captureRect {
            GroupBox {
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("X:")
                                .font(.callout)
                                .fontWeight(.medium)
                            TextField("X", value: xBinding(for: rect), format: .number)
                                .frame(width: 100)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Y:")
                                .font(.callout)
                                .fontWeight(.medium)
                            TextField("Y", value: yBinding(for: rect), format: .number)
                                .frame(width: 100)
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Width:")
                                .font(.callout)
                                .fontWeight(.medium)
                            TextField("Width", value: widthBinding(for: rect), format: .number)
                                .frame(width: 100)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Height:")
                                .font(.callout)
                                .fontWeight(.medium)
                            TextField("Height", value: heightBinding(for: rect), format: .number)
                                .frame(width: 100)
                        }
                        
                        Spacer()
                    }
                }
                .padding(12)
            } label: {
                Text("Coordinates & Size")
                    .font(.caption)
            }
            .padding(.top, 12)
        }
    }
    
    private func xBinding(for rect: CGRect) -> Binding<Double> {
        Binding(
            get: { Double(rect.origin.x) },
            set: { captureEngine.captureRect?.origin.x = CGFloat($0) }
        )
    }
    
    private func yBinding(for rect: CGRect) -> Binding<Double> {
        Binding(
            get: { Double(rect.origin.y) },
            set: { captureEngine.captureRect?.origin.y = CGFloat($0) }
        )
    }
    
    private func widthBinding(for rect: CGRect) -> Binding<Double> {
        Binding(
            get: { Double(rect.size.width) },
            set: { captureEngine.captureRect?.size.width = CGFloat($0) }
        )
    }
    
    private func heightBinding(for rect: CGRect) -> Binding<Double> {
        Binding(
            get: { Double(rect.size.height) },
            set: { captureEngine.captureRect?.size.height = CGFloat($0) }
        )
    }
}

// MARK: - Output Section
private struct OutputSection: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 16) {
                Text("Save To:")
                    .frame(width: 90, alignment: .trailing)
                Text(captureEngine.saveDirectory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: 350, alignment: .leading)
                    .help(captureEngine.saveDirectory.path)
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("Output")
        }
    }
}

// MARK: - Start Capture Button
private struct StartCaptureButton: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                captureEngine.startCapture()
            }) {
                Text("Start Capture")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
