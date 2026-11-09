import SwiftUI

struct DocumentListView: View {
    @Environment(DocumentStore.self) private var store

    @State private var path: [MazeDocument.ID] = []
    @State private var isCreating = false
    @State private var renaming: MazeDocument?
    @State private var renameText = ""
    @State private var deleting: MazeDocument?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            List(store.documents) { document in
                NavigationLink(value: document.id) {
                    DocumentRow(document: document)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = document }
                }
                .contextMenu {
                    Button("Duplicate", systemImage: "plus.square.on.square") {
                        attempt { try store.duplicate(document) }
                    }
                    Button("Rename", systemImage: "pencil") {
                        renameText = document.name
                        renaming = document
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = document }
                }
            }
            .overlay {
                if store.documents.isEmpty {
                    ContentUnavailableView {
                        Label("Start your first maze", systemImage: "square.grid.3x3")
                    } description: {
                        Text("Mazes you create are saved on this iPhone.")
                    } actions: {
                        Button("Create maze") { isCreating = true }
                    }
                }
            }
            .navigationTitle("Mazes")
            .navigationDestination(for: MazeDocument.ID.self) { id in
                EditorView(documentID: id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New maze", systemImage: "plus") { isCreating = true }
                }
            }
            .sheet(isPresented: $isCreating) {
                NewMazeSheet { name, width, height in
                    attempt {
                        let document = try store.create(name: name, width: width, height: height)
                        path = [document.id]
                    }
                }
            }
            .alert("Rename maze", isPresented: isPresenting($renaming), presenting: renaming) { document in
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    attempt { try store.rename(document, to: renameText) }
                }
            }
            .confirmationDialog(
                "Delete this maze?",
                isPresented: isPresenting($deleting),
                titleVisibility: .visible,
                presenting: deleting
            ) { document in
                Button("Delete \(document.name)", role: .destructive) {
                    attempt { try store.delete(document) }
                }
            } message: { _ in
                Text("This can't be undone.")
            }
            .alert("Couldn't save your change", isPresented: isPresenting($errorMessage), presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    private func attempt(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isPresenting<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } }
        )
    }
}

private struct DocumentRow: View {
    let document: MazeDocument

    var body: some View {
        HStack(spacing: 12) {
            MazeCanvas(maze: document.maze, wallThickness: 0.5, showsGrid: false)
                .frame(width: 40, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(.headline)
                Text("\(document.width) × \(document.height) · \(document.modifiedAt.formatted(.relative(presentation: .named)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DocumentListView()
        .environment(DocumentStore(directory: .temporaryDirectory.appending(path: "PreviewMazes")))
}
