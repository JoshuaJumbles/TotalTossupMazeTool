import Foundation
import Observation

/// Editing state for one open maze: the active tool, the stroke in progress and undo history.
@MainActor
@Observable
final class EditorModel {
    enum Tool: String, CaseIterable, Identifiable {
        case path = "Path"
        case erase = "Erase"

        var id: Self { self }
    }

    static let undoLimit = 100

    var tool = Tool.path
    var saveError: String?
    private(set) var document: MazeDocument
    private(set) var undoStack: [Maze] = []
    private(set) var redoStack: [Maze] = []

    private let store: DocumentStore
    /// The maze as it was when the current stroke began; nil between strokes.
    private var mazeBeforeStroke: Maze?
    private var lastCell: Cell?

    init(document: MazeDocument, store: DocumentStore) {
        self.document = document
        self.store = store
    }

    var maze: Maze { document.maze }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Extends the current stroke to `cell`, starting a new stroke if none is in progress.
    func drag(to cell: Cell) {
        guard let lastCell else {
            mazeBeforeStroke = maze
            apply(to: cell)
            lastCell = cell
            return
        }
        guard cell != lastCell else { return }
        switch tool {
        case .path:
            document.maze.carvePath(from: lastCell, to: cell)
        case .erase:
            Maze.steps(from: lastCell, to: cell).forEach(apply(to:))
        }
        self.lastCell = cell
    }

    /// Finishes the stroke: one undo step and one save, however many cells it touched.
    func endStroke() {
        defer {
            mazeBeforeStroke = nil
            lastCell = nil
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

    private func apply(to cell: Cell) {
        switch tool {
        case .path: document.maze.carve(cell)
        case .erase: document.maze.erase(cell)
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
