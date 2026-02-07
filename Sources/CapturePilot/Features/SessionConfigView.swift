import SwiftUI
import AppKit
import CoreGraphics

struct SessionConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var captureEngine = CaptureEngine.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if captureEngine.isCapturing {
                CapturingView(captureEngine: captureEngine, dismiss: dismiss)
            } else {
                ConfigurationView(captureEngine: captureEngine)
            }
        }
        .frame(width: 680, height: 580, alignment: .topLeading)
        .onAppear {
            captureEngine.onCaptureStopped = {
                dismiss()
            }
        }
        .onDisappear {
            captureEngine.onCaptureStopped = nil
        }
    }
}

private struct CapturingView: View {
    @ObservedObject var captureEngine: CaptureEngine
    let dismiss: DismissAction
    
    private var capturingAreaText: String {
        if let pid = captureEngine.selectedAppPID {
            // Get app name
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
                return "Capturing: \(app.localizedName ?? "Unknown App")"
            }
            return "Capturing: Application"
        } else if let rect = captureEngine.captureRect {
            return "Capturing: Custom Area (\(Int(rect.width))×\(Int(rect.height)))"
        } else {
            return "Capturing: Fullscreen"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Capturing area info
                Text(capturingAreaText)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Preview image
                if let image = captureEngine.lastCapturedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 240)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Waiting for first capture...")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
                
                // Capture count
                Text("\(captureEngine.captureCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("captures")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                // Stop button
                Button(action: {
                    captureEngine.stopCapture()
                }) {
                    Label("Stop Session", systemImage: "stop.fill")
                        .frame(minWidth: 180)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

private struct ConfigurationView: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CaptureSettingsSection(captureEngine: captureEngine)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    )
                
                OutputSection(captureEngine: captureEngine)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    )
                
                TargetSourceSection(captureEngine: captureEngine)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    )
                
                ShortcutsSection(captureEngine: captureEngine)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    )
                
                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct DirectoryPickerView: View {
    @ObservedObject var captureEngine: CaptureEngine
    @Environment(\.dismiss) private var dismiss
    @State private var customPath: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Save Location")
                .font(.headline)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current: \(captureEngine.saveDirectory.path)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                TextField("Or enter custom path...", text: $customPath)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 24)
            
            HStack(spacing: 16) {
                Button("Default") {
                    captureEngine.saveDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Choose Folder...") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            captureEngine.saveDirectory = url
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 20)
        }
    }
}

private struct CaptureSettingsSection: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(icon: "camera.fill", title: "Capture Settings")
            
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    
                    Text("Interval:")
                        .font(.callout)
                        .fontWeight(.medium)
                    
                    TextField("", value: $captureEngine.interval, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 4)
                    
                    Stepper("", value: $captureEngine.interval, in: 1...60, step: 1.0)
                        .labelsHidden()
                    
                    Text("seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                    
                    Spacer()
                    
                    Divider()
                        .frame(height: 24)
                    
                    Image(systemName: "keyboard.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    
                    Text("Auto-Key:")
                        .font(.callout)
                        .fontWeight(.medium)
                    
                    Picker("Auto-Key", selection: $captureEngine.automationKey) {
                        ForEach(AutomationKey.allCases) { key in
                            HStack {
                                Image(systemName: key.symbolName)
                                Text(key.rawValue)
                            }
                            .tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 140)
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

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
    
    private var captureTypeBinding: Binding<String> {
        Binding(
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
        )
    }
    
var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "viewfinder")
                    .font(.callout)
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.15))
                    )
                
                Picker("Type:", selection: captureTypeBinding) {
                    Label("Fullscreen", systemImage: "rectangle.fill")
                        .tag("Fullscreen")
                    Label("Application", systemImage: "app.fill")
                        .tag("App")
                    Label("Custom Area", systemImage: "crop")
                        .tag("Custom")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                Spacer()
                
                StartCaptureButton(captureEngine: captureEngine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 16)
            
            if captureEngine.selectedAppPID != nil {
                appPicker
                    .transition(.opacity)
            } else if captureEngine.captureRect != nil {
                CustomAreaEditor(captureEngine: captureEngine)
                    .transition(.opacity)
            }
        }
    }
    
    private var appPicker: some View {
        AppGridPicker(selectedAppPID: $captureEngine.selectedAppPID)
    }
}

private struct AppGridPicker: View {
    @Binding var selectedAppPID: pid_t?
    
    @State private var apps: [AppGridItem] = []
    @State private var hoveredPID: pid_t?
    @State private var isLoading = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 12, alignment: .top)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            
            GroupBox {
                if apps.isEmpty {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.1)
                            Text("Loading applications...")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "app.badge")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No running applications found.")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
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
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        if hovering {
                                            hoveredPID = app.pid
                                        } else if hoveredPID == app.pid {
                                            hoveredPID = nil
                                        }
                                    }
                                }
                                .onLongPressGesture {
                                }
                            }
                        }
                        .padding(12)
                    }
                    .frame(height: 260)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.caption)
                    Text("Applications")
                        .font(.caption)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: captureTypeValue)
        .onAppear {
            reloadApps()
        }
    }
    
    private var captureTypeValue: String {
        guard let pid = selectedAppPID else { return "" }
        return String(pid)
    }
    
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            if let selected = selectedAppName {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                    Text(selected)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .help(selected)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "cursorarrow")
                        .foregroundColor(.secondary)
                    Text("Click a tile to select")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                reloadApps()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.callout)
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
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
                withAnimation(.easeOut(duration: 0.3)) {
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
        if isHovered { return .accentColor.opacity(0.7) }
        return .secondary.opacity(0.3)
    }
    
    private var borderWidth: CGFloat {
        if isSelected { return 2.5 }
        if isHovered { return 1.5 }
        return 1
    }
    
    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    preview
                        .frame(height: 110)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.title3)
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    Text(app.name)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tileBackground)
            .overlay(tileOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isHovered ? 1.03 : (isSelected ? 1.0 : 1.0))
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel(Text(app.name))
        .accessibilityHint(Text("Select application"))
    }
    
    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(NSColor.controlBackgroundColor),
                        Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.95 : 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(
                color: isSelected
                    ? Color.accentColor.opacity(0.2)
                    : Color.black.opacity(isHovered ? 0.12 : 0.06),
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 4 : 2
            )
    }
    
    private var tileOverlay: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(borderColor, lineWidth: borderWidth)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
    }
    
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(NSColor.windowBackgroundColor),
                            Color(NSColor.textBackgroundColor)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            if let thumbnail = app.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct CustomAreaEditor: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        if let rect = captureEngine.captureRect {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    coordinateField(icon: "xmark", title: "X:", value: xBinding(for: rect))
                    coordinateField(icon: "y", title: "Y:", value: yBinding(for: rect))
                    Spacer()
                }
                
                HStack(spacing: 20) {
                    coordinateField(icon: "arrow.left.and.right", title: "Width:", value: widthBinding(for: rect))
                    coordinateField(icon: "arrow.up.and.down", title: "Height:", value: heightBinding(for: rect))
                    Spacer()
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
            )
        }
    }
    
    private func coordinateField(icon: String, title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            TextField("", value: value, format: .number)
                .frame(width: 100)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 4)
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

private struct OutputSection: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Save To")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(captureEngine.saveDirectory.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .help(captureEngine.saveDirectory.path)
                        
                        Button("Choose Folder...") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            panel.begin { response in
                                if response == .OK, let url = panel.url {
                                    captureEngine.saveDirectory = url
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Spacer()
            }
        }
    }
}

private struct SectionHeaderView: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.15))
                )
            
            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

private struct StartCaptureButton: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        Button(action: {
            captureEngine.startCapture()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.caption2)
                Text("Start")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(minWidth: 80)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

private struct ShortcutsSection: View {
    @ObservedObject var captureEngine: CaptureEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(icon: "menubar.rectangle", title: "Menu Bar Control")
            
            VStack(spacing: 12) {
                // Hide window toggle
                Toggle(isOn: $captureEngine.hideWindowOnCapture) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        Text("Hide window while capturing")
                            .font(.callout)
                    }
                }
                .toggleStyle(.checkbox)
                
                Divider()
                
                // Menu bar info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        Text("When capture starts, the window will hide and a menu bar icon will appear")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        Text("Click the menu bar icon to stop capture and show the window")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

extension AutomationKey {
    var symbolName: String {
        switch self {
        case .space: return "space"
        case .rightArrow: return "arrow.right"
        case .leftArrow: return "arrow.left"
        case .pageDown: return "arrow.down.to.line"
        case .none: return "xmark"
        }
    }
}
