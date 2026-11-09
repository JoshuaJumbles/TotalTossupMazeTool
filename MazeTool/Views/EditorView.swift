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
        let analysis = model.analysis

        GeometryReader { screen in
            // Wider than tall, as on an iPad in landscape: controls move beside the maze so
            // it keeps the full height.
            if screen.size.width > screen.size.height {
                HStack(spacing: 0) {
                    canvas(analysis)
                    sideBar(analysis)
                }
            } else {
                canvas(analysis)
                    .safeAreaInset(edge: .bottom) { bottomBar(analysis) }
            }
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

    private func canvas(_ analysis: MazeAnalysis) -> some View {
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
    }

    /// Controls under the maze: chips in a row, then the tools.
    private func bottomBar(_ analysis: MazeAnalysis) -> some View {
        @Bindable var model = model

        return VStack(spacing: 10) {
            HStack {
                SymmetryChip(symmetry: $model.symmetry)
                Spacer()
                actionButtons
                Spacer()
                raceButton(analysis)
            }
            Picker("Tool", selection: $model.tool) {
                ForEach(EditorModel.Tool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)
        }
        // Keeps the controls a comfortable width on an iPad in portrait.
        .frame(maxWidth: 560)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        // Hidden rather than removed while previewing, so the maze doesn't shift.
        .opacity(isPreviewing ? 0 : 1)
        .disabled(isPreviewing)
    }

    /// Controls beside the maze: the tools in a column, then the chips.
    private func sideBar(_ analysis: MazeAnalysis) -> some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(EditorModel.Tool.allCases) { tool in
                Button {
                    model.tool = tool
                } label: {
                    Label(tool.rawValue, systemImage: tool.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            model.tool == tool ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.tool == tool ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .accessibilityAddTraits(model.tool == tool ? .isSelected : [])
            }
            Spacer()
            SymmetryChip(symmetry: $model.symmetry)
            HStack { actionButtons }
            raceButton(analysis)
        }
        .frame(width: 180)
        .padding(.vertical, 12)
        .padding(.trailing, 12)
        .opacity(isPreviewing ? 0 : 1)
        .disabled(isPreviewing)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
            .modifier(ChipIconStyle(tint: .secondary))
        if viewport.isZoomed {
            Button("Zoom to fit", systemImage: "arrow.down.right.and.arrow.up.left") { viewport = Viewport() }
                .modifier(ChipIconStyle(tint: .accentColor))
        }
        Button("Export", systemImage: "square.and.arrow.up") { isShowingExport = true }
            .modifier(ChipIconStyle(tint: .secondary))
    }

    private func raceButton(_ analysis: MazeAnalysis) -> some View {
        Button {
            isShowingRace = true
        } label: {
            RaceChip(analysis: analysis)
        }
        .buttonStyle(.plain)
    }

    private var isPresentingSaveError: Binding<Bool> {
        Binding(
            get: { model.saveError != nil },
            set: { if !$0 { model.saveError = nil } }
        )
    }
}

/// A round icon button matching the chips beside it.
private struct ChipIconStyle: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(8)
            .background(.thinMaterial, in: Circle())
    }
}

private extension EditorModel.Tool {
    var systemImage: String {
        switch self {
        case .path: "scribble"
        case .double: "equal"
        case .room: "square.dashed"
        case .mark: "flag"
        case .erase: "eraser"
        }
    }
}
