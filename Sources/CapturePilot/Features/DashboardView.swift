import SwiftUI
import CoreData

struct DashboardView: View {
    @State private var showingNewSession = false
    
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
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        VStack(alignment: .leading) {
                            Text(session.date, style: .date)
                                .font(.headline)
                            Text(session.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            
            Text("Select a session")
                .foregroundStyle(.secondary)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { sessions[$0] }.forEach(PersistenceController.shared.container.viewContext.delete)
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
