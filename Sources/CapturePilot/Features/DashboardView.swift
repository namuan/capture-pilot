import SwiftUI
import CoreData

struct DashboardView: View {
    @State private var showingNewSession = false
    @State private var showingDeleteAlert = false
    @State private var sessionsToDelete: [CaptureSession]?
    @State private var selectedSession: CaptureSession?
    @State private var selectedSessions = Set<UUID>()
    @State private var isMultiSelectMode = false

    // Fetch sessions
    // Note: Since we are not using standard Xcode gen, we might need a manual FetchRequest if the class isn't found,
    // but usually FetchRequest works if the class is registered.
    // For MVP transparency, I'll simulate a list or use a simpler persistence if Core Data gives trouble in this setup.
    // But let's try standard.
    @FetchRequest(
        entity: CaptureSession.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CaptureSession.date, ascending: false)],
        animation: .default)
    private var sessions: FetchedResults<CaptureSession>
    
    var body: some View {
        NavigationView {
            List(selection: $selectedSessions) {
                ForEach(sessions, id: \.id) { session in
                    Button {
                        if isMultiSelectMode {
                            toggleSessionSelection(session)
                        } else {
                            selectedSession = session
                        }
                    } label: {
                        HStack {
                            if isMultiSelectMode {
                                Image(systemName: selectedSessions.contains(session.id) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedSessions.contains(session.id) ? .accentColor : .secondary)
                                    .font(.system(size: 16))
                                    .frame(width: 24)
                            }

                            VStack(alignment: .leading) {
                                Text(session.date, style: .date)
                                    .font(.headline)
                                Text(session.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if !isMultiSelectMode && selectedSession == session {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selectedSessions.contains(session.id) && isMultiSelectMode ? Color.accentColor.opacity(0.1) : Color.clear)
                    .contextMenu {
                        if !isMultiSelectMode {
                            Button(role: .destructive) {
                                sessionsToDelete = [session]
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 280)
            .navigationTitle(isMultiSelectMode ? "\(selectedSessions.count) Selected" : "Sessions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        if isMultiSelectMode {
                            Button(role: .destructive) {
                                sessionsToDelete = sessions.filter { selectedSessions.contains($0.id) }
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(selectedSessions.isEmpty)

                            Button {
                                if selectedSessions.count == sessions.count {
                                    selectedSessions.removeAll()
                                } else {
                                    selectedSessions = Set(sessions.map { $0.id })
                                }
                            } label: {
                                Image(systemName: selectedSessions.count == sessions.count ? "minus.square" : "checkmark.square")
                            }
                            .disabled(sessions.isEmpty)

                            Button {
                                isMultiSelectMode = false
                                selectedSessions.removeAll()
                            } label: {
                                Text("Done")
                            }
                            .keyboardShortcut(.escape, modifiers: [])
                        } else {
                            if !sessions.isEmpty {
                                Button {
                                    isMultiSelectMode = true
                                    selectedSessions.removeAll()
                                } label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                }
                            }

                            Button(action: { showingNewSession = true }) {
                                Label("New Session", systemImage: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewSession, onDismiss: {
                // Refresh selection when sheet closes (new session might have been created)
                if let lastSession = sessions.first {
                    selectedSession = lastSession
                }
            }) {
                SessionConfigView()
            }
            .alert("Delete \(sessionsToDelete?.count == 1 ? "Session" : "Sessions")?", isPresented: $showingDeleteAlert, presenting: sessionsToDelete) { sessions in
                Button("Delete", role: .destructive) {
                    performDelete(sessions)
                }
                Button("Cancel", role: .cancel) {}
            } message: { sessions in
                Text("This will permanently remove \(sessions.count) session(s) and all captured images from the disk. This action cannot be undone.")
            }
            
            // Detail view area
            detailView
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let session = selectedSession, sessions.contains(where: { $0.id == session.id }) {
            SessionDetailView(session: session)
                .id(session.id)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                if sessions.isEmpty {
                    Text("No sessions available")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Click + to start a new capture session")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                } else {
                    Text("Select a session to view screenshots")
                        .font(.title3)
                        .foregroundColor(.secondary)
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
        if selectedSessions.contains(session.id) {
            selectedSessions.remove(session.id)
        } else {
            selectedSessions.insert(session.id)
        }
    }

    private func performDelete(_ sessionsToRemove: [CaptureSession]) {
        withAnimation {
            for session in sessionsToRemove {
                if session == selectedSession {
                    selectedSession = nil
                }

                // Delete folder
                let path = session.path
                if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                    try? FileManager.default.removeItem(atPath: path)
                }

                // Delete from Core Data
                PersistenceController.shared.container.viewContext.delete(session)
            }

            try? PersistenceController.shared.container.viewContext.save()

            // Clear selection after delete
            if isMultiSelectMode {
                selectedSessions.removeAll()
                isMultiSelectMode = false
            }
        }
    }
}

struct SessionDetailView: View {
    let session: CaptureSession
    @State private var images: [URL] = []
    @State private var selectedImage: URL? = nil
    @State private var isLoading = true
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading screenshots...")
                    .scaleEffect(1.2)
                    .padding(.top, 100)
            } else if images.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No screenshots captured yet")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(images, id: \.self) { imageURL in
                        ScreenshotThumbnail(imageURL: imageURL)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedImage = imageURL
                                }
                            }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(Text(session.date, style: .date))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                    Text("\(images.count) captures")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadImages()
        }
        .onChange(of: session.path) { _ in
            loadImages()
        }
        .sheet(item: $selectedImage) { imageURL in
            ImagePreviewView(imageURL: imageURL)
        }
    }
    
    private func loadImages() {
        isLoading = true
        images = []
        
        let path = session.path
        print("Loading images from path: \(path)")
        
        guard !path.isEmpty else {
            print("Path is empty, skipping load")
            isLoading = false
            return
        }
        
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        guard fileManager.fileExists(atPath: path) else {
            print("Directory does not exist at path: \(path)")
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                let imageFiles = contents
                    .filter { $0.pathExtension.lowercased() == "png" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                
                print("Found \(imageFiles.count) images in \(path)")
                
                DispatchQueue.main.async {
                    self.images = imageFiles
                    self.isLoading = false
                }
            } catch {
                print("Error loading images: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

struct ScreenshotThumbnail: View {
    let imageURL: URL
    @State private var image: NSImage? = nil
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
                .shadow(
                    color: isHovered ? .blue.opacity(0.3) : .black.opacity(0.15),
                    radius: isHovered ? 12 : 6,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
            
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(4)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
                    .padding(4)
            }
        }
        .aspectRatio(16/10, contentMode: .fit)
        .onAppear {
            loadThumbnail()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOf: imageURL) {
                let resized = image.resized(to: NSSize(width: 400, height: 250))
                DispatchQueue.main.async {
                    self.image = resized
                }
            }
        }
    }
}

struct ImagePreviewView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var image: NSImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // macOS-style title bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(imageURL.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        if let image = image {
                            pasteboard.writeObjects([image])
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Copy Image")
                    .disabled(image == nil)
                    
                    Button {
                        NSWorkspace.shared.open(imageURL)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Open in Finder")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(nsColor: .separatorColor)),
                alignment: .bottom
            )
            
            // Image content fills all remaining space
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                scale = 1.0
                                lastScale = 1.0
                            }
                        }
                } else {
                    ProgressView("Loading image...")
                        .scaleEffect(1.2)
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOf: imageURL) {
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
}

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .high
        
        draw(in: NSRect(origin: .zero, size: newSize), 
             from: NSRect(origin: .zero, size: size), 
             operation: .copy, 
             fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
