import SwiftUI

struct EditorView: View {
    let documentID: MazeDocument.ID

    @Environment(DocumentStore.self) private var store

    var body: some View {
        if let document = store.document(id: documentID) {
            EditorScreen(document: document, store: store)
        } else {
            ContentUnavailableView("Maze not found", systemImage: "questionmark.square.dashed")
        }
    }
}

private struct EditorScreen: View {
    @State private var model: EditorModel

    init(document: MazeDocument, store: DocumentStore) {
        _model = State(initialValue: EditorModel(document: document, store: store))
    }

    var body: some View {
        @Bindable var model = model

        GeometryReader { proxy in
            let geometry = GridGeometry(columns: model.maze.width, rows: model.maze.height, size: proxy.size)
            MazeCanvas(
                maze: model.maze,
                wallThickness: model.document.settings.wallThickness,
                roomPreview: model.roomPreview,
                canPlaceRoomPreview: model.canPlaceRoomPreview
            )
            .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Strokes must start on the grid, but may run past its edge.
                            guard geometry.frame.contains(value.startLocation) else { return }
                            model.drag(to: geometry.nearestCell(to: value.location))
                        }
                        .onEnded { _ in model.endStroke() }
                )
        }
        .padding(8)
        .safeAreaInset(edge: .bottom) {
            Picker("Tool", selection: $model.tool) {
                ForEach(EditorModel.Tool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle(model.document.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                    .disabled(!model.canUndo)
                Button("Redo", systemImage: "arrow.uturn.forward") { model.redo() }
                    .disabled(!model.canRedo)
            }
        }
        .alert("Couldn't save your maze", isPresented: isPresentingSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.saveError ?? "")
        }
    }

    private var isPresentingSaveError: Binding<Bool> {
        Binding(
            get: { model.saveError != nil },
            set: { if !$0 { model.saveError = nil } }
        )
    }
}
