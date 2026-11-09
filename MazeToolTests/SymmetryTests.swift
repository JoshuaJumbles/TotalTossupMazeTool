import Foundation
import Testing
@testable import MazeTool

@MainActor
struct SymmetryTests {
    private let directory = URL.temporaryDirectory.appending(path: "MazeToolTests-\(UUID().uuidString)")

    /// An 8 × 6 grid, so cell x mirrors to 7 − x and cell y to 5 − y.
    private func makeModel(_ symmetry: Symmetry) throws -> EditorModel {
        let store = DocumentStore(directory: directory)
        let model = EditorModel(document: try store.create(name: "Test", width: 8, height: 6), store: store)
        model.symmetry = symmetry
        return model
    }

    private func cell(_ x: Int, _ y: Int) -> Cell { Cell(x: x, y: y) }

    private func stroke(_ model: EditorModel, _ tool: EditorModel.Tool, _ cells: Cell...) {
        model.tool = tool
        cells.forEach { model.drag(to: $0, vertex: $0) }
        model.endStroke()
    }

    private func carvedCells(_ maze: Maze) -> Set<Cell> {
        var cells: Set<Cell> = []
        for y in 0..<maze.height {
            for x in 0..<maze.width where maze.isCarved(cell(x, y)) {
                cells.insert(cell(x, y))
            }
        }
        return cells
    }

    @Test(arguments: [
        (Symmetry.leftRight, Cell(x: 7, y: 1), Cell(x: 5, y: 2)),
        (Symmetry.topBottom, Cell(x: 0, y: 4), Cell(x: 2, y: 3)),
        (Symmetry.rotate, Cell(x: 7, y: 4), Cell(x: 5, y: 3)),
    ])
    func pathIsRepeatedAsItsMirrorImage(symmetry: Symmetry, mirroredStart: Cell, mirroredEnd: Cell) throws {
        let model = try makeModel(symmetry)

        // (0,1) east to (2,1), then south to (2,2).
        stroke(model, .path, cell(0, 1), cell(2, 1), cell(2, 2))

        #expect(model.maze.isOpen(cell(0, 1), cell(1, 1)))
        #expect(model.maze.isOpen(cell(2, 1), cell(2, 2)))
        #expect(model.maze.isCarved(mirroredStart))
        #expect(model.maze.isCarved(mirroredEnd))
        #expect(carvedCells(model.maze).count == 8)
        #expect(model.undoStack.count == 1)
    }

    @Test func offCarvesOnlyTheStrokeItself() throws {
        let model = try makeModel(.off)

        stroke(model, .path, cell(0, 1), cell(2, 1))

        #expect(carvedCells(model.maze) == [cell(0, 1), cell(1, 1), cell(2, 1)])
    }

    @Test func eraseIsMirroredToo() throws {
        let model = try makeModel(.leftRight)
        stroke(model, .path, cell(0, 1), cell(2, 1))

        stroke(model, .erase, cell(1, 1), cell(2, 1))

        #expect(carvedCells(model.maze) == [cell(0, 1), cell(7, 1)])
    }

    @Test func roomIsPlacedWithItsMirrorImage() throws {
        let model = try makeModel(.rotate)

        stroke(model, .room, cell(0, 0), cell(1, 1))

        #expect(model.maze.rooms.count == 2)
        #expect(model.maze.room(at: cell(7, 5)) != nil)
        #expect(model.maze.room(at: cell(6, 4)) != nil)
        #expect(model.undoStack.count == 1)
    }

    @Test func roomThatIsItsOwnMirrorImageIsPlacedOnce() throws {
        let model = try makeModel(.leftRight)

        stroke(model, .room, cell(3, 1), cell(4, 2))

        #expect(model.maze.rooms.count == 1)
    }

    @Test func roomThatWouldOverlapItsMirrorImageIsNotPlaced() throws {
        let model = try makeModel(.leftRight)
        model.tool = .room

        model.drag(to: cell(2, 1))
        model.drag(to: cell(4, 2))
        #expect(model.roomPreviews.count == 2)
        #expect(!model.canPlaceRoomPreview)
        model.endStroke()

        #expect(model.maze.rooms.isEmpty)
        #expect(!model.canUndo)
    }

    @Test func erasingARoomRemovesItsMirrorImage() throws {
        let model = try makeModel(.topBottom)
        stroke(model, .room, cell(1, 0), cell(2, 1))

        stroke(model, .erase, cell(1, 5))

        #expect(model.maze.rooms.isEmpty)
        #expect(model.maze.isEmpty)
    }

    @Test func markingIsNotMirrored() throws {
        let model = try makeModel(.leftRight)
        stroke(model, .room, cell(0, 0), cell(1, 1))

        stroke(model, .mark, cell(0, 0))

        #expect(model.maze.room(at: cell(0, 0))?.marker == .blueStart)
        #expect(model.maze.room(at: cell(7, 0))?.marker == nil)
    }

    @Test func doublePathIsMirroredIntoFourSeparateCorridors() throws {
        let model = try makeModel(.leftRight)

        // Vertices (1,1) → (3,1) → (3,4); the mirror runs (7,1) → (5,1) → (5,4).
        stroke(model, .double, cell(1, 1), cell(3, 1), cell(3, 4))

        var endCount = 0
        for carved in carvedCells(model.maze) {
            let degree = Direction.allCases.filter { model.maze.isOpen(carved, carved.neighbor($0)) }.count
            #expect((1...2).contains(degree))
            if degree == 1 { endCount += 1 }
        }
        #expect(endCount == 8)
        for carved in carvedCells(model.maze) {
            #expect(model.maze.isCarved(cell(7 - carved.x, carved.y)))
        }
    }

    @Test func doublePathRewindRemovesBothImages() throws {
        let model = try makeModel(.rotate)

        stroke(model, .double, cell(1, 1), cell(3, 1), cell(1, 1))

        #expect(model.maze.isEmpty)
    }
}
