import Foundation
import Observation

/// Editing state for one open maze: the active tool, the stroke in progress and undo history.
@MainActor
@Observable
final class EditorModel {
    enum Tool: String, CaseIterable, Identifiable {
        case path = "Path"
        case double = "Double"
        case room = "Room"
        case mark = "Mark"
        case erase = "Erase"

        var id: Self { self }
    }

    static let undoLimit = 100

    var tool = Tool.path
    var saveError: String?
    /// The issue picked from the race sheet; its cells stay ringed until the next stroke.
    var highlightedIssue: MazeIssue?
    private(set) var document: MazeDocument
    private(set) var undoStack: [Maze] = []
    private(set) var redoStack: [Maze] = []
    /// The room being dragged out with the room tool; added to the maze when the stroke ends.
    private(set) var roomPreview: Room?

    private let store: DocumentStore
    /// The maze as it was when the current stroke began; nil between strokes.
    private var mazeBeforeStroke: Maze?
    private var firstCell: Cell?
    private var lastCell: Cell?
    /// Grid vertices the double-path stroke has traced so far, along the wall between its two corridors.
    private var doubleVertices: [Cell] = []
    /// The maze before each double-path step was carved, so dragging back can rewind it.
    private var doubleSnapshots: [Maze] = []

    init(document: MazeDocument, store: DocumentStore) {
        self.document = document
        self.store = store
    }

    var maze: Maze { document.maze }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var canPlaceRoomPreview: Bool { roomPreview.map(maze.canAddRoom) ?? false }
    var analysis: MazeAnalysis { MazeAnalysis(maze: maze, stepsPerMove: stepsPerMove) }

    /// A game rule rather than a drawing edit, so it saves straight away and isn't undoable.
    var stepsPerMove: Int {
        get { document.settings.stepsPerMove }
        set {
            document.settings.stepsPerMove = newValue
            save()
        }
    }

    /// Extends the current stroke to `cell`, starting a new stroke if none is in progress.
    /// `vertex` is the grid vertex nearest the touch, which the double-path tool follows instead.
    func drag(to cell: Cell, vertex: Cell? = nil) {
        guard let firstCell, let lastCell else {
            mazeBeforeStroke = maze
            highlightedIssue = nil
            firstCell = cell
            lastCell = cell
            doubleVertices = vertex.map { [$0] } ?? []
            beginStroke(at: cell)
            return
        }
        if tool == .double {
            vertex.map(extendDoublePath)
            return
        }
        guard cell != lastCell else { return }
        switch tool {
        case .path:
            document.maze.carvePath(from: lastCell, to: cell)
        case .double:
            break
        case .room:
            roomPreview = Room(from: firstCell, to: cell)
        case .mark:
            break
        case .erase:
            // Dragging over a room leaves it alone; only a stroke that starts on a room removes it.
            Maze.steps(from: lastCell, to: cell).forEach { document.maze.erase($0) }
        }
        self.lastCell = cell
    }

    /// Finishes the stroke: one undo step and one save, however many cells it touched.
    func endStroke() {
        if let roomPreview {
            document.maze.addRoom(roomPreview)
        }
        defer {
            roomPreview = nil
            mazeBeforeStroke = nil
            firstCell = nil
            lastCell = nil
            doubleVertices = []
            doubleSnapshots = []
        }
        guard let mazeBeforeStroke, mazeBeforeStroke != maze else { return }
        undoStack.append(mazeBeforeStroke)
        if undoStack.count > Self.undoLimit {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        save()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(maze)
        document.maze = previous
        save()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(maze)
        document.maze = next
        save()
    }

    private func extendDoublePath(to vertex: Cell) {
        guard let last = doubleVertices.last else {
            doubleVertices = [vertex]
            return
        }
        for step in Maze.steps(from: last, to: vertex) {
            let before = doubleVertices.dropLast().last
            // Dragging back over the line just drawn rewinds that step. Carving there instead
            // would swap the corridors' sides and join them.
            if step == before {
                doubleVertices.removeLast()
                document.maze = doubleSnapshots.removeLast()
                continue
            }
            doubleSnapshots.append(maze)
            document.maze.carveDoublePath(from: doubleVertices[doubleVertices.count - 1], to: step, after: before)
            doubleVertices.append(step)
        }
    }

    private func beginStroke(at cell: Cell) {
        switch tool {
        case .path:
            document.maze.carve(cell)
        case .double:
            // Needs a second vertex before there is a line to carve along.
            break
        case .room:
            roomPreview = Room(from: cell, to: cell)
        case .mark:
            document.maze.cycleMarker(at: cell)
        case .erase:
            if !document.maze.removeRoom(at: cell) {
                document.maze.erase(cell)
            }
        }
    }

    private func save() {
        do {
            try store.save(document)
        } catch {
            saveError = error.localizedDescription
        }
    }
}
