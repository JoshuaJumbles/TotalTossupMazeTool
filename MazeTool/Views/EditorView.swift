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
    @State private var viewport = Viewport()
    /// The viewport when the pinch in progress began, and where its centre was; nil between pinches.
    @State private var pinchStart: (viewport: Viewport, anchor: CGPoint)?
    /// Where and when the current one-finger drag began. A pinch can cancel a drag without
    /// its end being reported, so a new drag is told apart by its start location.
    @State private var dragStart: (location: CGPoint, time: Date)?
    /// Drags that began before this are the first finger of a pinch, and don't draw.
    @State private var lastPinchTime = Date.distantPast

    init(document: MazeDocument, store: DocumentStore) {
        _model = State(initialValue: EditorModel(document: document, store: store))
    }

    var body: some View {
        @Bindable var model = model
        let analysis = model.analysis

        GeometryReader { proxy in
            let geometry = GridGeometry(
                columns: model.maze.width, rows: model.maze.height, size: viewport.contentSize(in: proxy.size)
            )
            MazeCanvas(
                maze: model.maze,
                wallThickness: model.wallThickness,
                isPreview: isPreviewing,
                viewport: viewport,
                roomPreviews: model.roomPreviews,
                canPlaceRoomPreview: model.canPlaceRoomPreview,
                analysis: analysis,
                highlightedIssue: model.highlightedIssue,
                symmetry: model.symmetry
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart?.location != value.startLocation {
                            dragStart = (value.startLocation, .now)
                        }
                        // One finger draws. A drag that turns out to be half of a pinch doesn't.
                        guard !isPreviewing, pinchStart == nil, let dragStart, dragStart.time > lastPinchTime else { return }
                        // Strokes must start on the grid, but may run past its edge.
                        guard geometry.frame.contains(viewport.contentPoint(for: value.startLocation)) else { return }
                        let point = viewport.contentPoint(for: value.location)
                        model.drag(to: geometry.nearestCell(to: point), vertex: geometry.nearestVertex(to: point))
                    }
                    .onEnded { _ in
                        dragStart = nil
                        model.endStroke()
                    }
            )
            .gesture(
                PinchPanGesture(
                    onBegan: { value in
                        // The first finger may already have started drawing; take that back.
                        model.cancelStroke()
                        lastPinchTime = .now
                        pinchStart = (viewport, value.location)
                    },
                    onChanged: { value in
                        guard let pinchStart else { return }
                        viewport = Viewport.pinched(
                            from: pinchStart.viewport, anchor: pinchStart.anchor,
                            location: value.location, scale: value.scale, in: proxy.size
                        )
                    },
                    onEnded: {
                        lastPinchTime = .now
                        pinchStart = nil
                    }
                )
            )
            .onChange(of: proxy.size) { viewport.clamp(in: proxy.size) }
        }
        .clipped()
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
                    if viewport.isZoomed {
                        Button("Zoom to fit", systemImage: "arrow.down.right.and.arrow.up.left") {
                            viewport = Viewport()
                        }
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(8)
                        .background(.thinMaterial, in: Circle())
                    }
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
