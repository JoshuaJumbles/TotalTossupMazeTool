import CoreGraphics
import Foundation
import Testing
@testable import MazeTool

@MainActor
struct EditorModelTests {
    private let directory = URL.temporaryDirectory.appending(path: "MazeToolTests-\(UUID().uuidString)")

    private func makeModel() throws -> (EditorModel, DocumentStore) {
        let store = DocumentStore(directory: directory)
        let document = try store.create(name: "Test", width: 6, height: 6)
        return (EditorModel(document: document, store: store), store)
    }

    @Test func tapCarvesOneCell() throws {
        let (model, _) = try makeModel()

        model.drag(to: Cell(x: 2, y: 2))
        model.endStroke()

        #expect(model.maze.isCarved(Cell(x: 2, y: 2)))
        #expect(model.undoStack.count == 1)
    }

    @Test func pathStrokeConnectsCellsAndSavesOnEnd() throws {
        let (model, store) = try makeModel()

        model.drag(to: Cell(x: 0, y: 0))
        model.drag(to: Cell(x: 1, y: 0))
        model.drag(to: Cell(x: 3, y: 0))
        model.endStroke()

        #expect(model.maze.isOpen(Cell(x: 0, y: 0), Cell(x: 1, y: 0)))
        #expect(model.maze.isOpen(Cell(x: 2, y: 0), Cell(x: 3, y: 0)))
        let saved = DocumentStore(directory: directory).document(id: model.document.id)
        #expect(saved?.maze == model.maze)
        #expect(store.document(id: model.document.id)?.maze == model.maze)
    }

    @Test func wholeStrokeIsOneUndoStep() throws {
        let (model, _) = try makeModel()
        model.drag(to: Cell(x: 0, y: 0))
        model.drag(to: Cell(x: 4, y: 0))
        model.endStroke()
        let drawn = model.maze

        model.undo()
        #expect(model.maze.isEmpty)
        #expect(!model.canUndo)

        model.redo()
        #expect(model.maze == drawn)
        #expect(!model.canRedo)
    }

    @Test func newStrokeClearsRedo() throws {
        let (model, _) = try makeModel()
        model.drag(to: Cell(x: 0, y: 0))
        model.endStroke()
        model.undo()

        model.drag(to: Cell(x: 1, y: 1))
        model.endStroke()

        #expect(!model.canRedo)
    }

    @Test func strokeThatChangesNothingAddsNoUndoStep() throws {
        let (model, _) = try makeModel()
        model.tool = .erase

        model.drag(to: Cell(x: 0, y: 0))
        model.endStroke()

        #expect(!model.canUndo)
    }

    @Test func eraseStrokeRemovesEveryCellItCrosses() throws {
        let (model, _) = try makeModel()
        model.drag(to: Cell(x: 0, y: 0))
        model.drag(to: Cell(x: 5, y: 0))
        model.endStroke()

        model.tool = .erase
        model.drag(to: Cell(x: 1, y: 0))
        model.drag(to: Cell(x: 3, y: 0))
        model.endStroke()

        #expect(model.maze.isCarved(Cell(x: 0, y: 0)))
        #expect(!model.maze.isCarved(Cell(x: 1, y: 0)))
        #expect(!model.maze.isCarved(Cell(x: 2, y: 0)))
        #expect(!model.maze.isCarved(Cell(x: 3, y: 0)))
        #expect(model.maze.isOpen(Cell(x: 4, y: 0), Cell(x: 5, y: 0)))
        #expect(!model.maze.isOpen(Cell(x: 3, y: 0), Cell(x: 4, y: 0)))
    }
}

struct GridGeometryTests {
    @Test func gridIsCentredAndPointsMapToCells() {
        let geometry = GridGeometry(columns: 4, rows: 2, size: CGSize(width: 100, height: 100))

        #expect(geometry.cellSize == 25)
        #expect(geometry.frame == CGRect(x: 0, y: 25, width: 100, height: 50))
        #expect(geometry.nearestCell(to: CGPoint(x: 30, y: 30)) == Cell(x: 1, y: 0))
        #expect(geometry.nearestCell(to: CGPoint(x: 99, y: 74)) == Cell(x: 3, y: 1))
        #expect(geometry.rect(for: Cell(x: 1, y: 1)) == CGRect(x: 25, y: 50, width: 25, height: 25))
    }

    @Test func pointsOutsideTheGridClampToTheEdge() {
        let geometry = GridGeometry(columns: 4, rows: 2, size: CGSize(width: 100, height: 100))

        #expect(geometry.nearestCell(to: CGPoint(x: -20, y: 0)) == Cell(x: 0, y: 0))
        #expect(geometry.nearestCell(to: CGPoint(x: 500, y: 500)) == Cell(x: 3, y: 1))
    }
}
