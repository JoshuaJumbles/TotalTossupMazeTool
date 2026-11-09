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
    @State private var isShowingRace = false
    @State private var isShowingSettings = false
    @State private var isShowingExport = false
    @State private var isPreviewing = false

    init(document: MazeDocument, store: DocumentStore) {
        _model = State(initialValue: EditorModel(document: document, store: store))
    }

    var body: some View {
        @Bindable var model = model
        let analysis = model.analysis

        GeometryReader { proxy in
            let geometry = GridGeometry(columns: model.maze.width, rows: model.maze.height, size: proxy.size)
            MazeCanvas(
                maze: model.maze,
                wallThickness: model.wallThickness,
                isPreview: isPreviewing,
                roomPreviews: model.roomPreviews,
                canPlaceRoomPreview: model.canPlaceRoomPreview,
                analysis: analysis,
                highlightedIssue: model.highlightedIssue,
                symmetry: model.symmetry
            )
            .contentShape(Rectangle())
            .allowsHitTesting(!isPreviewing)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Strokes must start on the grid, but may run past its edge.
                            guard geometry.frame.contains(value.startLocation) else { return }
                            model.drag(
                                to: geometry.nearestCell(to: value.location),
                                vertex: geometry.nearestVertex(to: value.location)
                            )
                        }
                        .onEnded { _ in model.endStroke() }
                )
        }
        .padding(8)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                HStack {
                    SymmetryChip(symmetry: $model.symmetry)
                    Spacer()
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.thinMaterial, in: Circle())
                    Button("Export", systemImage: "square.and.arrow.up") { isShowingExport = true }
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.thinMaterial, in: Circle())
                    Spacer()
                    Button {
                        isShowingRace = true
                    } label: {
                        RaceChip(analysis: analysis)
                    }
                    .buttonStyle(.plain)
                }
                Picker("Tool", selection: $model.tool) {
                    ForEach(EditorModel.Tool.allCases) { tool in
                        Text(tool.rawValue).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            // Hidden rather than removed while previewing, so the maze doesn't shift.
            .opacity(isPreviewing ? 0 : 1)
            .disabled(isPreviewing)
        }
        .sheet(isPresented: $isShowingRace) {
            RaceSheet(model: model)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheet(model: model)
        }
        .sheet(isPresented: $isShowingExport) {
            ExportSheet(document: model.document)
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
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                Toggle("Preview", systemImage: isPreviewing ? "eye.fill" : "eye", isOn: $isPreviewing)
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
