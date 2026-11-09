import Foundation
import Testing
@testable import MazeTool

struct MazeTests {
    @Test func connectCarvesBothCellsAndOpensTheEdgeBothWays() {
        var maze = Maze(width: 4, height: 4)
        let a = Cell(x: 1, y: 1)
        let b = Cell(x: 2, y: 1)

        maze.connect(a, b)

        #expect(maze.isCarved(a))
        #expect(maze.isCarved(b))
        #expect(maze.isOpen(a, b))
        #expect(maze.isOpen(b, a))
        #expect(!maze.isOpen(a, Cell(x: 1, y: 2)))
    }

    @Test func connectIgnoresCellsThatAreNotNeighbours() {
        var maze = Maze(width: 4, height: 4)

        maze.connect(Cell(x: 0, y: 0), Cell(x: 1, y: 1))
        maze.connect(Cell(x: 3, y: 0), Cell(x: 4, y: 0))

        #expect(maze.isEmpty)
    }

    @Test func eraseFillsTheCellAndClosesItsConnections() {
        var maze = Maze(width: 4, height: 4)
        maze.carvePath(from: Cell(x: 0, y: 1), to: Cell(x: 2, y: 1))
        maze.connect(Cell(x: 1, y: 1), Cell(x: 1, y: 2))

        maze.erase(Cell(x: 1, y: 1))

        #expect(!maze.isCarved(Cell(x: 1, y: 1)))
        #expect(!maze.isOpen(Cell(x: 0, y: 1), Cell(x: 1, y: 1)))
        #expect(!maze.isOpen(Cell(x: 1, y: 1), Cell(x: 2, y: 1)))
        #expect(!maze.isOpen(Cell(x: 1, y: 1), Cell(x: 1, y: 2)))
        #expect(maze.isCarved(Cell(x: 0, y: 1)))
        #expect(maze.isCarved(Cell(x: 1, y: 2)))
    }

    @Test func stepsAreCardinalAndEndOnTheTarget() {
        let start = Cell(x: 0, y: 0)
        let end = Cell(x: 3, y: -2)

        let steps = Maze.steps(from: start, to: end)

        #expect(steps.count == 5)
        #expect(steps.last == end)
        var previous = start
        for step in steps {
            #expect(abs(step.x - previous.x) + abs(step.y - previous.y) == 1)
            previous = step
        }
        #expect(Maze.steps(from: start, to: start).isEmpty)
    }

    @Test func carvePathConnectsEveryStepOfADiagonalDrag() {
        var maze = Maze(width: 6, height: 6)
        let start = Cell(x: 0, y: 0)
        let end = Cell(x: 4, y: 3)

        maze.carvePath(from: start, to: end)

        var previous = start
        for step in Maze.steps(from: start, to: end) {
            #expect(maze.isOpen(previous, step))
            previous = step
        }
    }

    @Test func codingRoundTripsCellsAndConnections() throws {
        var maze = Maze(width: 5, height: 3)
        maze.carvePath(from: Cell(x: 0, y: 0), to: Cell(x: 4, y: 0))
        maze.carvePath(from: Cell(x: 4, y: 0), to: Cell(x: 4, y: 2))
        maze.carve(Cell(x: 0, y: 2))

        let decoded = try JSONDecoder().decode(Maze.self, from: JSONEncoder().encode(maze))

        #expect(decoded == maze)
    }

    @Test func decodingRejectsRowsOfTheWrongSize() {
        let json = ###"{"width":2,"height":2,"cells":["##","#"],"right":["..",".."],"down":["..",".."]}"###

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Maze.self, from: Data(json.utf8))
        }
    }
}
