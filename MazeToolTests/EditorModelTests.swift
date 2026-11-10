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

    @Test func cancelledStrokeLeavesNoTraceAndNoUndoStep() throws {
        let (model, _) = try makeModel()
        model.drag(to: Cell(x: 0, y: 0))
        model.endStroke()
        let before = model.maze

        model.drag(to: Cell(x: 3, y: 3))
        model.drag(to: Cell(x: 5, y: 3))
        model.cancelStroke()

        #expect(model.maze == before)
        #expect(model.undoStack.count == 1)

        model.tool = .room
        model.drag(to: Cell(x: 2, y: 2))
        model.drag(to: Cell(x: 4, y: 4))
        model.cancelStroke()

        #expect(model.maze == before)
        #expect(model.roomPreviews.isEmpty)
    }

    @Test func settingsSaveStraightAwayWithoutAnUndoStep() throws {
        let (model, _) = try makeModel()

        model.wallThickness = 5
        model.stepsPerMove = 3

        let saved = DocumentStore(directory: directory).document(id: model.document.id)
        #expect(saved?.settings.wallThickness == 5)
        #expect(saved?.settings.stepsPerMove == 3)
        #expect(!model.canUndo)
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

    @Test func blockLinesPairCellsFromBothEdgesAndLeaveOddCellsInTheMiddle() {
        // Even counts divide cleanly into pairs.
        #expect(GridGeometry.blockLines(count: 16) == [2, 4, 6, 8, 10, 12, 14])
        #expect(GridGeometry.blockLines(count: 18) == [2, 4, 6, 8, 10, 12, 14, 16])
        // 17 = 8 + 1 + 8: a single column down the middle.
        #expect(GridGeometry.blockLines(count: 17) == [2, 4, 6, 8, 9, 11, 13, 15])
        // 15 = 6 + 3 + 6: pairs can't reach the middle evenly, so three columns are left.
        #expect(GridGeometry.blockLines(count: 15) == [2, 4, 6, 9, 11, 13])
        #expect(GridGeometry.blockLines(count: 5) == [2, 3])
        #expect(GridGeometry.blockLines(count: 3).isEmpty)
    }

    @Test func pointsOutsideTheGridClampToTheEdge() {
        let geometry = GridGeometry(columns: 4, rows: 2, size: CGSize(width: 100, height: 100))

        #expect(geometry.nearestCell(to: CGPoint(x: -20, y: 0)) == Cell(x: 0, y: 0))
        #expect(geometry.nearestCell(to: CGPoint(x: 500, y: 500)) == Cell(x: 3, y: 1))
    }
}
