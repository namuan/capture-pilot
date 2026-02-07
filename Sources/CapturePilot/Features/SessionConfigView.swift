import SwiftUI
import AppKit
import CoreGraphics

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
        .frame(width: 650, height: 550, alignment: .topLeading)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            StartCaptureButton(captureEngine: captureEngine)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }
}

// MARK: - Capture Settings Section
private struct CaptureSettingsSection: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        Section {
            HStack(alignment: .center, spacing: 8) {
                Text("Interval:")
                
                TextField("", value: $captureEngine.interval, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                
                Stepper("", value: $captureEngine.interval, in: 0.5...60, step: 0.5)
                    .labelsHidden()
                
                Text("s")
                    .foregroundColor(.secondary)
                
                Spacer()
                    .frame(width: 24)
                
                Text("Auto-Key:")
                
                Picker("Auto-Key", selection: $captureEngine.automationKey) {
                    ForEach(AutomationKey.allCases) { key in
                        Text(key.rawValue).tag(key)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }
        } header: {
            Text("Capture Settings")
        }
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
        AppGridPicker(selectedAppPID: $captureEngine.selectedAppPID)
            .padding(.top, 12)
    }
}

// MARK: - Application Grid Picker
private struct AppGridPicker: View {
    @Binding var selectedAppPID: pid_t?

    @State private var apps: [AppGridItem] = []
    @State private var hoveredPID: pid_t?
    @State private var isLoading = false

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            GroupBox {
                if apps.isEmpty {
                    if isLoading {
                        ProgressView("Loading applications...")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        Text("No running applications found.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                            ForEach(apps) { app in
                                AppGridTile(
                                    app: app,
                                    isSelected: selectedAppPID == app.pid,
                                    isHovered: hoveredPID == app.pid
                                ) {
                                    selectedAppPID = app.pid
                                }
                                .onHover { hovering in
                                    if hovering {
                                        hoveredPID = app.pid
                                    } else if hoveredPID == app.pid {
                                        hoveredPID = nil
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                    .frame(height: 250)
                }
            } label: {
                Text("Applications")
                    .font(.caption)
            }
        }
        .onAppear {
            reloadApps()
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Application:")
                .frame(width: 90, alignment: .trailing)

            if let selected = selectedAppName {
                Text(selected)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .help(selected)
            } else {
                Text("Click a tile to select")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                reloadApps()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Refresh application previews")
        }
    }

    private var selectedAppName: String? {
        guard let pid = selectedAppPID else { return nil }
        return apps.first(where: { $0.pid == pid })?.name
    }

    private func reloadApps() {
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }

        let baseItems = runningApps
            .map { app in
                AppGridItem(
                    pid: app.processIdentifier,
                    name: app.localizedName ?? "Unknown",
                    icon: app.icon,
                    thumbnail: nil
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        apps = baseItems
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let windowInfoList = WindowImageProvider.windowInfoList()
            let withThumbs: [AppGridItem] = baseItems.map { item in
                var item = item
                item.thumbnail = WindowImageProvider.windowThumbnail(forPID: item.pid, windowInfoList: windowInfoList, maxDimension: 520)
                return item
            }

            DispatchQueue.main.async {
                apps = withThumbs
                isLoading = false

                if let selected = selectedAppPID, apps.contains(where: { $0.pid == selected }) {
                    return
                }
                selectedAppPID = apps.first?.pid
            }
        }
    }
}

private enum WindowImageProvider {
    static func windowInfoList() -> [[String: Any]] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        return (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []
    }

    static func windowThumbnail(forPID pid: pid_t, windowInfoList: [[String: Any]], maxDimension: CGFloat) -> NSImage? {
        guard let windowID = bestWindowID(forPID: pid, windowInfoList: windowInfoList) else { return nil }

        let imageOptions: CGWindowImageOption = [.bestResolution, .boundsIgnoreFraming]
        guard let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, imageOptions) else { return nil }

        let scaled = scaledImage(cgImage, maxDimension: maxDimension) ?? cgImage
        return NSImage(cgImage: scaled, size: NSSize(width: scaled.width, height: scaled.height))
    }

    private static func bestWindowID(forPID pid: pid_t, windowInfoList: [[String: Any]]) -> CGWindowID? {
        var best: (id: CGWindowID, area: CGFloat)?

        for info in windowInfoList {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid else { continue }

            let isOnscreen = boolValue(info[kCGWindowIsOnscreen as String]) ?? true
            guard isOnscreen else { continue }

            let alpha = cgFloat(info[kCGWindowAlpha as String]) ?? 1
            guard alpha > 0.05 else { continue }

            let layer = intValue(info[kCGWindowLayer as String]) ?? 0
            guard layer == 0 else { continue }

            guard let bounds = windowBounds(from: info) else { continue }
            guard bounds.width >= 120, bounds.height >= 90 else { continue }

            guard let windowNumber = intValue(info[kCGWindowNumber as String]), windowNumber > 0 else { continue }
            let windowID = CGWindowID(windowNumber)

            let area = bounds.width * bounds.height
            if let current = best {
                if area > current.area {
                    best = (windowID, area)
                }
            } else {
                best = (windowID, area)
            }
        }

        return best?.id
    }

    private static func windowBounds(from info: [String: Any]) -> CGRect? {
        guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any] else { return nil }
        guard let x = cgFloat(boundsDict["X"]),
              let y = cgFloat(boundsDict["Y"]),
              let w = cgFloat(boundsDict["Width"]),
              let h = cgFloat(boundsDict["Height"]) else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func scaledImage(_ image: CGImage, maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let maxSide = max(width, height)
        guard maxSide > maxDimension, maxDimension > 0 else { return nil }

        let scale = maxDimension / maxSide
        let newWidth = max(1, Int((width * scale).rounded(.toNearestOrAwayFromZero)))
        let newHeight = max(1, Int((height * scale).rounded(.toNearestOrAwayFromZero)))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(newWidth), height: CGFloat(newHeight)))
        return ctx.makeImage()
    }

    private static func cgFloat(_ value: Any?) -> CGFloat? {
        switch value {
        case let v as CGFloat:
            return v
        case let v as Double:
            return CGFloat(v)
        case let v as Int:
            return CGFloat(v)
        case let v as NSNumber:
            return CGFloat(truncating: v)
        default:
            return nil
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let v as Int:
            return v
        case let v as NSNumber:
            return v.intValue
        default:
            return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let v as Bool:
            return v
        case let v as NSNumber:
            return v.boolValue
        default:
            return nil
        }
    }
}

private struct AppGridItem: Identifiable {
    let pid: pid_t
    let name: String
    let icon: NSImage?
    var thumbnail: NSImage?

    var id: pid_t { pid }
}

private struct AppGridTile: View {
    let app: AppGridItem
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    private var borderColor: Color {
        if isSelected { return .accentColor }
        if isHovered { return .accentColor.opacity(0.65) }
        return .secondary.opacity(0.25)
    }

    private var borderWidth: CGFloat {
        if isSelected { return 2 }
        if isHovered { return 1.5 }
        return 1
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    preview
                        .frame(height: 110)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(6)
                    }
                }

                Text(app.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tileBackground)
            .overlay(tileOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(isHovered ? 1.02 : 1)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel(Text(app.name))
        .accessibilityHint(Text("Select application"))
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor))
            .shadow(color: Color.black.opacity(isHovered ? 0.10 : 0.05), radius: isHovered ? 6 : 2, x: 0, y: isHovered ? 4 : 1)
    }

    private var tileOverlay: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(borderColor, lineWidth: borderWidth)
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))

            if let thumbnail = app.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .padding(22)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.secondary.opacity(0.18), lineWidth: 1)
        )
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
        .padding(.top, 16)
    }
}
