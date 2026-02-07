import SwiftUI
import CoreData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct DashboardView: View {
    @State private var showingNewSession = false
    @State private var showingDeleteAlert = false
    @State private var sessionsToDelete: [CaptureSession]?
    @State private var selectedSession: CaptureSession?
    @State private var selectedSessions = Set<UUID>()
    @State private var isMultiSelectMode = false

    @FetchRequest(
        entity: CaptureSession.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CaptureSession.date, ascending: false)],
        animation: .default)
    private var sessions: FetchedResults<CaptureSession>

    // removed matched-geometry namespace — we animate thumbnails separately

    var body: some View {
        NavigationView {
            // Left column: custom scrollable stack of card-like session rows.
            ScrollView {
                LazyVStack(spacing: 8, pinnedViews: []) {
                    ForEach(sessions, id: \.id) { session in
                        SessionRow(session: session,
                                   isSelected: selectedSessions.contains(session.id),
                                   isMultiSelectMode: isMultiSelectMode,
                                   isActive: selectedSession?.objectID == session.objectID)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isMultiSelectMode {
                                    toggleSessionSelection(session)
                                } else {
                                    withAnimation(.spring()) { selectedSession = session }
                                }
                            }
                            .onLongPressGesture(minimumDuration: 0.35) {
                                triggerHaptic()
                                if !isMultiSelectMode {
                                    isMultiSelectMode = true
                                    selectedSessions.removeAll()
                                    selectedSessions.insert(session.id)
                                }
                            }
                            .background(selectedSessions.contains(session.id) && isMultiSelectMode ? Color.accentColor.opacity(0.06) : Color.clear)
                            .contextMenu {
                                if !isMultiSelectMode {
                                    Button(role: .destructive) {
                                        sessionsToDelete = [session]
                                        showingDeleteAlert = true
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.top, 12)
            }
            .frame(minWidth: 340)
            .background(Color(NSColor.windowBackgroundColor))
            .navigationTitle(isMultiSelectMode ? "\(selectedSessions.count) Selected" : "Sessions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        if isMultiSelectMode {
                            Button(role: .destructive) { sessionsToDelete = sessions.filter { selectedSessions.contains($0.id) }; showingDeleteAlert = true } label: { Label("Delete", systemImage: "trash") }
                                .disabled(selectedSessions.isEmpty)

                            Button { if selectedSessions.count == sessions.count { selectedSessions.removeAll() } else { selectedSessions = Set(sessions.map { $0.id }) } } label: { Image(systemName: selectedSessions.count == sessions.count ? "minus.square" : "checkmark.square") }
                                .disabled(sessions.isEmpty)

                            Button { isMultiSelectMode = false; selectedSessions.removeAll() } label: { Text("Done") }
                                .keyboardShortcut(.escape, modifiers: [])
                        } else {
                            if !sessions.isEmpty {
                                Button { isMultiSelectMode = true; selectedSessions.removeAll() } label: { Label("Select", systemImage: "checkmark.circle") }
                            }
                            Button(action: { showingNewSession = true }) { Label("New Session", systemImage: "plus") }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewSession) { SessionConfigView() }
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text((sessionsToDelete?.count == 1) ? "Delete Session?" : "Delete Sessions?"),
                    message: Text("This will permanently remove \(sessionsToDelete?.count ?? 0) session(s) and all captured images from the disk. This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete"), action: { performDelete(sessionsToDelete ?? []) }),
                    secondaryButton: .cancel()
                )
            }

            detailView
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }

    // Toolbar is defined inline in the view chain above. Previously this
    // computed property returned ToolbarItem values which confused the
    // Swift parser because ToolbarItem is not a View. Keeping the toolbar
    // inline fixes parsing and avoids duplicate definitions.

    @ViewBuilder private var detailView: some View {
            if let session = selectedSession, sessions.contains(where: { $0.objectID == session.objectID }) {
            SessionDetailView(session: session)
                .id(session.id)
            } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                if sessions.isEmpty {
                    Text("No sessions available").font(.title3).foregroundColor(.secondary)
                    Text("Click + to start a new capture session").font(.caption).foregroundColor(.secondary.opacity(0.7))
                } else {
                    Text("Select a session to view screenshots").font(.title3).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    private func deleteItems(offsets: IndexSet) {
        sessionsToDelete = offsets.map { sessions[$0] }
        showingDeleteAlert = true
    }

    private func toggleSessionSelection(_ session: CaptureSession) {
        if selectedSessions.contains(session.id) { selectedSessions.remove(session.id) } else { selectedSessions.insert(session.id) }
    }

    private func performDelete(_ sessionsToRemove: [CaptureSession]) {
        // Do deletions safely on the viewContext thread. Collect objectIDs and paths
        // first so we don't retain faulted objects across threads and can re-fetch
        // them on the correct context.
        let context = PersistenceController.shared.container.viewContext
        let idsAndPaths = sessionsToRemove.map { (objectID: $0.objectID, path: $0.path) }
        let selectedID = selectedSession?.objectID

        // Clear selection immediately if the selected session will be deleted to
        // avoid SwiftUI accessing a managed object that is deleted from the
        // persistent store while the view system is reading its properties.
        if let selectedID = selectedID, idsAndPaths.contains(where: { $0.objectID == selectedID }) {
            selectedSession = nil
        }

        context.perform {
            withAnimation {
                for (objectID, path) in idsAndPaths {
                    if let obj = try? context.existingObject(with: objectID) as? CaptureSession {
                        if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                            try? FileManager.default.removeItem(atPath: path)
                        }
                        context.delete(obj)
                    }
                }

                do { try context.save() } catch {
                    print("Failed saving context after delete: \(error)")
                }

                DispatchQueue.main.async {
                    if isMultiSelectMode { selectedSessions.removeAll(); isMultiSelectMode = false }
                }
            }
        }
    }
}

fileprivate func triggerHaptic() {
    #if os(macOS)
    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    #else
    let g = UINotificationFeedbackGenerator(); g.notificationOccurred(.success)
    #endif
}

struct SessionRow: View {
    let session: CaptureSession
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let isActive: Bool
    // This row is animated when active so the list thumbnail remains visible

    @State private var thumbnail: NSImage? = nil
    @State private var imageCount: Int? = nil
    @State private var isHover = false

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail: remove decorative gradient border and show the
            // image edge-to-edge inside a rounded rect. Keep the hover
            // shadow but avoid an extra framed border around the image.
            Group {
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    // lightweight placeholder background so rows don't jump
                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08))
                        .overlay(Image(systemName: "photo").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary))
                }
            }
            .frame(width: 72, height: 48)
            .clipped()
            .shadow(color: isHover ? Color.black.opacity(0.25) : Color.black.opacity(0.12), radius: isHover ? 8 : 4, x: 0, y: isHover ? 6 : 2)
            // subtle list-side animation when the row becomes active (selection)
            .opacity(isActive ? 0.78 : 1.0)
            .scaleEffect(isActive ? 0.985 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: isActive)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.date, style: .date).font(.headline)
                Text(session.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer()

            if isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").foregroundColor(isSelected ? .accentColor : .secondary).font(.system(size: 18))
            } else {
                HStack(spacing: 8) {
                    if let count = imageCount { Text("\(count)").font(.caption).foregroundStyle(.secondary) }
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        // subtle selected-state treatment: add a faint accent stroke and
        // very light tint when this row is the active selection. Keep the
        // stronger shadow only for multi-select (isSelected) to avoid
        // visual noise.
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.accentColor.opacity(0.14) : Color.clear, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive ? Color.accentColor.opacity(0.03) : Color.clear)
                )
                .shadow(color: isSelected ? Color.accentColor.opacity(0.12) : Color.clear, radius: 8, x: 0, y: 4)
        )
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.18)) { isHover = hovering } }
        .onAppear { loadMetadata() }
        .animation(.easeInOut(duration: 0.18), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: isActive)
    }

    private func loadMetadata() {
        let path = session.path
        guard !path.isEmpty else { imageCount = 0; return }
        let url = URL(fileURLWithPath: path)
        ImageCache.shared.loadFirstImage(in: url, targetSize: NSSize(width: 400, height: 250)) { count, img in
            self.imageCount = count
            self.thumbnail = img
        }
    }
}

struct SessionDetailView: View {
    let session: CaptureSession
    @State private var images: [URL] = []
    @State private var selectedImageIndex: Int? = nil
    @State private var isLoading = true

    private let columns = [ GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16) ]

    private var selectedImageBinding: Binding<Int> {
        Binding(get: { selectedImageIndex ?? 0 }, set: { selectedImageIndex = $0 })
    }

    private var formattedDate: String { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f.string(from: session.date) }

    var body: some View {
        ScrollView {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.date, style: .date).font(.title2).fontWeight(.semibold)
                    Text(session.path).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }

                Spacer()
            }
            .padding([.top, .horizontal])

            Divider()

            if isLoading {
                ProgressView("Loading screenshots...").scaleEffect(1.2).padding(.top, 100)
            } else if images.isEmpty {
                VStack(spacing: 16) { Image(systemName: "photo.on.rectangle.angled").font(.system(size: 48)).foregroundColor(.secondary); Text("No screenshots captured yet").foregroundColor(.secondary) }
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(images.enumerated()), id: \.element) { index, imageURL in
                        ScreenshotThumbnail(imageURL: imageURL)
                            .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedImageIndex = index } }
                    }
                }
                .padding()
            }
        }
        // Header title is redundant with the in-view metadata; keep the
        // navigation title empty so the window header doesn't duplicate info.
        .navigationTitle("")
        .onAppear { loadImages() }
        .onChange(of: session.path) { _ in loadImages() }
        .sheet(isPresented: Binding(get: { selectedImageIndex != nil }, set: { if !$0 { selectedImageIndex = nil } })) {
            if selectedImageIndex != nil { ImagePreviewView(images: images, currentIndex: selectedImageBinding) }
        }
    }

    private func loadImages() {
        isLoading = true; images = []
        let path = session.path
        guard !path.isEmpty else { isLoading = false; return }
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { isLoading = false; return }
        DispatchQueue.global(qos: .userInitiated).async {
            if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                let imageFiles = contents.filter { $0.pathExtension.lowercased() == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
                DispatchQueue.main.async { self.images = imageFiles; self.isLoading = false }
            } else { DispatchQueue.main.async { self.isLoading = false } }
        }
    }
}

struct ScreenshotThumbnail: View {
    let imageURL: URL
    @State private var image: NSImage? = nil
    @State private var isHovered = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)).shadow(color: isHovered ? .blue.opacity(0.3) : .black.opacity(0.15), radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 4 : 2)
            if let image = image { Image(nsImage: image).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 10)).padding(4) }
            else { RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)).overlay(ProgressView().scaleEffect(0.8)).padding(4) }
        }
        .aspectRatio(16/10, contentMode: .fit)
        .onAppear { ImageCache.shared.loadImage(from: imageURL, targetSize: NSSize(width: 400, height: 250)) { img in self.image = img } }
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.2)) { isHovered = hovering } }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct ImagePreviewView: View {
    let images: [URL]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var image: NSImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isTransitioning = false

    private var currentImageURL: URL { images[currentIndex] }
    private var canGoPrevious: Bool { currentIndex > 0 }
    private var canGoNext: Bool { currentIndex < images.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(.secondary) }
                    .buttonStyle(.plain).focusable(false)
                Spacer()
                HStack(spacing: 16) {
                    Button { goToPrevious() } label: { Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold)) }
                        .buttonStyle(.plain).disabled(!canGoPrevious).keyboardShortcut(.leftArrow, modifiers: [])
                    Text("\(currentIndex + 1) of \(images.count)").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary).frame(minWidth: 80)
                    Button { goToNext() } label: { Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold)) }
                        .buttonStyle(.plain).disabled(!canGoNext).keyboardShortcut(.rightArrow, modifiers: [])
                }
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        let pasteboard = NSPasteboard.general; pasteboard.clearContents(); if let image = image { pasteboard.writeObjects([image]) }
                    } label: { Image(systemName: "doc.on.doc").font(.system(size: 16)) }
                    .buttonStyle(.plain).help("Copy Image").disabled(image == nil)

                    Button { NSWorkspace.shared.open(currentImageURL) } label: { Image(systemName: "arrow.up.right.square").font(.system(size: 16)) }
                        .buttonStyle(.plain).help("Open in Finder")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12).background(Color(nsColor: .windowBackgroundColor)).overlay(Rectangle().frame(height: 0.5).foregroundColor(Color(nsColor: .separatorColor)), alignment: .bottom)

            ZStack { Color(nsColor: .underPageBackgroundColor)
                if let image = image, !isTransitioning {
                    Image(nsImage: image).resizable().scaledToFit().scaleEffect(scale).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .gesture(MagnificationGesture().onChanged { value in scale = lastScale * value }.onEnded { _ in lastScale = scale })
                        .onTapGesture(count: 2) { withAnimation(.spring()) { scale = 1.0; lastScale = 1.0 } }
                } else { ProgressView("Loading image...").scaleEffect(1.2) }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear { loadImage() }
        .onChange(of: currentIndex) { _ in resetZoom(); loadImage() }
    }

    private func goToPrevious() { guard canGoPrevious, !isTransitioning else { return }; withAnimation(.easeInOut(duration: 0.15)) { isTransitioning = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { currentIndex -= 1; withAnimation(.easeInOut(duration: 0.15)) { isTransitioning = false } } }
    private func goToNext() { guard canGoNext, !isTransitioning else { return }; withAnimation(.easeInOut(duration: 0.15)) { isTransitioning = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { currentIndex += 1; withAnimation(.easeInOut(duration: 0.15)) { isTransitioning = false } } }
    private func resetZoom() { withAnimation(.spring()) { scale = 1.0; lastScale = 1.0 } }
    private func loadImage() { DispatchQueue.global(qos: .userInitiated).async { if let img = NSImage(contentsOf: currentImageURL) { DispatchQueue.main.async { self.image = img } } } }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }
