import SwiftUI
import CoreData

struct DashboardView: View {
    @State private var showingNewSession = false
    @State private var showingDeleteAlert = false
    @State private var sessionsToDelete: [CaptureSession]?
    @State private var selectedSession: CaptureSession?
    
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
            List {
                ForEach(sessions, id: \.id) { session in
                    NavigationLink(destination: SessionDetailView(session: session), tag: session, selection: $selectedSession) {
                        VStack(alignment: .leading) {
                            Text(session.date, style: .date)
                                .font(.headline)
                            Text(session.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            sessionsToDelete = [session]
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewSession = true }) {
                        Label("New Session", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSession) {
                SessionConfigView()
            }
            .alert("Delete Session?", isPresented: $showingDeleteAlert, presenting: sessionsToDelete) { sessions in
                Button("Delete", role: .destructive) {
                    performDelete(sessions)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This will permanently remove the session and all captured images from the disk. This action cannot be undone.")
            }
            
            Text("Select a session")
                .foregroundStyle(.secondary)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        sessionsToDelete = offsets.map { sessions[$0] }
        showingDeleteAlert = true
    }
    
    private func performDelete(_ sessions: [CaptureSession]) {
        withAnimation {
            for session in sessions {
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
        }
    }
}

struct SessionDetailView: View {
    let session: CaptureSession
    
    var body: some View {
        Text("Session Details for \(session.date)")
            .navigationTitle("Session")
    }
}
