import CoreGraphics
import Foundation
import Testing
@testable import MazeTool

struct DoublePathTests {
    private func cell(_ x: Int, _ y: Int) -> Cell { Cell(x: x, y: y) }

    /// Carves along a polyline of vertices, one grid step at a time.
    private func carve(_ maze: inout Maze, along corners: [Cell]) {
        var traced = [corners[0]]
        for corner in corners.dropFirst() {
            for step in Maze.steps(from: traced[traced.count - 1], to: corner) {
                maze.carveDoublePath(from: traced[traced.count - 1], to: step, after: traced.dropLast().last)
                traced.append(step)
            }
        }
    }

    private func openConnectionCount(in maze: Maze) -> Int {
        var count = 0
        for y in 0..<maze.height {
            for x in 0..<maze.width {
                for direction in [Direction.right, .down] where maze.isOpen(cell(x, y), cell(x, y).neighbor(direction)) {
                    count += 1
                }
            }
        }
        return count
    }

    @Test func oneStepCarvesACellOnEachSideOfTheLineWithAWallBetween() {
        var maze = Maze(width: 6, height: 6)

        maze.carveDoublePath(from: cell(1, 2), to: cell(2, 2))

        #expect(maze.isCarved(cell(1, 1)))
        #expect(maze.isCarved(cell(1, 2)))
        #expect(!maze.isOpen(cell(1, 1), cell(1, 2)))
        #expect(openConnectionCount(in: maze) == 0)
    }

    @Test func straightRunMakesTwoSeparateCorridors() {
        var maze = Maze(width: 6, height: 6)

        carve(&maze, along: [cell(1, 2), cell(4, 2)])

        for x in 1..<3 {
            #expect(maze.isOpen(cell(x, 1), cell(x + 1, 1)))
            #expect(maze.isOpen(cell(x, 2), cell(x + 1, 2)))
        }
        for x in 1...3 {
            #expect(!maze.isOpen(cell(x, 1), cell(x, 2)))
        }
        #expect(openConnectionCount(in: maze) == 4)
    }

    @Test func turnPivotsTheInsideCorridorAndWrapsTheOutsideOneAroundTheCorner() {
        var maze = Maze(width: 6, height: 6)

        // East along y = 3, then north up x = 3: a left turn, so the upper corridor is inside.
        carve(&maze, along: [cell(1, 3), cell(3, 3), cell(3, 1)])

        // Inside: (1,2) → (2,2) pivots and continues north to (2,1).
        #expect(maze.isOpen(cell(1, 2), cell(2, 2)))
        #expect(maze.isOpen(cell(2, 2), cell(2, 1)))
        // Outside: (1,3) → (2,3) → corner (3,3) → (3,2) → (3,1).
        #expect(maze.isOpen(cell(1, 3), cell(2, 3)))
        #expect(maze.isOpen(cell(2, 3), cell(3, 3)))
        #expect(maze.isOpen(cell(3, 3), cell(3, 2)))
        #expect(maze.isOpen(cell(3, 2), cell(3, 1)))
        // The corridors never touch.
        #expect(!maze.isOpen(cell(2, 2), cell(2, 3)))
        #expect(!maze.isOpen(cell(2, 2), cell(3, 2)))
        #expect(!maze.isOpen(cell(2, 1), cell(3, 1)))
        #expect(openConnectionCount(in: maze) == 6)
    }

    @Test(arguments: [
        [Cell(x: 2, y: 2), Cell(x: 5, y: 2), Cell(x: 5, y: 5), Cell(x: 2, y: 5)],
        [Cell(x: 5, y: 5), Cell(x: 2, y: 5), Cell(x: 2, y: 2), Cell(x: 5, y: 2)],
        [Cell(x: 2, y: 5), Cell(x: 2, y: 2), Cell(x: 4, y: 2), Cell(x: 4, y: 4), Cell(x: 6, y: 4)],
    ])
    func everyTurnDirectionKeepsTwoUnbranchedCorridors(corners: [Cell]) {
        var maze = Maze(width: 8, height: 8)

        carve(&maze, along: corners)

        // Two simple corridors: every carved cell has one or two connections, and exactly four have one.
        var endCount = 0
        for y in 0..<8 {
            for x in 0..<8 where maze.isCarved(cell(x, y)) {
                let degree = Direction.allCases.filter { maze.isOpen(cell(x, y), cell(x, y).neighbor($0)) }.count
                #expect((1...2).contains(degree))
                if degree == 1 { endCount += 1 }
            }
        }
        #expect(endCount == 4)
    }

    @Test func nearestVertexRoundsToGridLinesAndStaysOffTheBorder() {
        let geometry = GridGeometry(columns: 4, rows: 4, size: CGSize(width: 100, height: 100))

        #expect(geometry.nearestVertex(to: CGPoint(x: 49, y: 62)) == cell(2, 2))
        #expect(geometry.nearestVertex(to: CGPoint(x: 63, y: 62)) == cell(3, 2))
        #expect(geometry.nearestVertex(to: CGPoint(x: 2, y: 99)) == cell(1, 3))
    }
}

@MainActor
struct DoublePathEditingTests {
    private let directory = URL.temporaryDirectory.appending(path: "MazeToolTests-\(UUID().uuidString)")

    private func makeModel() throws -> EditorModel {
        let store = DocumentStore(directory: directory)
        let model = EditorModel(document: try store.create(name: "Test", width: 8, height: 8), store: store)
        model.tool = .double
        return model
    }

    private func drag(_ model: EditorModel, through vertices: Cell...) {
        vertices.forEach { model.drag(to: $0, vertex: $0) }
    }

    @Test func dragCarvesBothCorridorsAsOneUndoStep() throws {
        let model = try makeModel()

        drag(model, through: Cell(x: 1, y: 2), Cell(x: 5, y: 2), Cell(x: 5, y: 6))
        model.endStroke()

        #expect(model.maze.isOpen(Cell(x: 1, y: 1), Cell(x: 2, y: 1)))
        #expect(model.maze.isOpen(Cell(x: 1, y: 2), Cell(x: 2, y: 2)))
        #expect(model.maze.isOpen(Cell(x: 5, y: 1), Cell(x: 5, y: 2)))
        #expect(model.undoStack.count == 1)

        model.undo()
        #expect(model.maze.isEmpty)
    }

    @Test func tapWithoutDraggingCarvesNothing() throws {
        let model = try makeModel()

        drag(model, through: Cell(x: 3, y: 3))
        model.endStroke()

        #expect(model.maze.isEmpty)
        #expect(!model.canUndo)
    }

    @Test func draggingBackRewindsTheOvershootSoALaterTurnStaysClean() throws {
        let overshot = try makeModel()
        drag(overshot, through: Cell(x: 1, y: 3), Cell(x: 5, y: 3), Cell(x: 3, y: 3), Cell(x: 3, y: 6))
        overshot.endStroke()

        let direct = try makeModel()
        drag(direct, through: Cell(x: 1, y: 3), Cell(x: 3, y: 3), Cell(x: 3, y: 6))
        direct.endStroke()

        #expect(overshot.maze == direct.maze)
        #expect(!overshot.maze.isCarved(Cell(x: 4, y: 2)))
        #expect(overshot.undoStack.count == 1)
    }

    @Test func draggingAllTheWayBackLeavesTheMazeUntouched() throws {
        let model = try makeModel()

        drag(model, through: Cell(x: 1, y: 3), Cell(x: 5, y: 3), Cell(x: 1, y: 3))
        model.endStroke()

        #expect(model.maze.isEmpty)
        #expect(!model.canUndo)
    }
}
