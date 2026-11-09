import Foundation
import Testing
@testable import MazeTool

struct MazeAnalysisTests {
    /// Adds a one-cell or larger room and cycles its marker until it matches.
    private func addRoom(_ maze: inout Maze, _ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, _ marker: Room.Marker?) {
        maze.addRoom(Room(from: Cell(x: x1, y: y1), to: Cell(x: x2, y: y2)))
        while maze.room(at: Cell(x: x1, y: y1))?.marker != marker {
            maze.cycleMarker(at: Cell(x: x1, y: y1))
        }
    }

    private func path(_ maze: inout Maze, _ points: (Int, Int)...) {
        for (start, end) in zip(points, points.dropFirst()) {
            maze.carvePath(from: Cell(x: start.0, y: start.1), to: Cell(x: end.0, y: end.1))
        }
    }

    private func steps(_ route: Route?) -> [Int] {
        route?.stops.map(\.step) ?? []
    }

    /// Blue: Start, two corners, End. Three steps.
    private func twoCornerMaze() -> Maze {
        var maze = Maze(width: 10, height: 10)
        addRoom(&maze, 0, 0, 0, 0, .blueStart)
        addRoom(&maze, 8, 3, 8, 3, .end)
        path(&maze, (0, 0), (4, 0), (4, 3), (8, 3))
        return maze
    }

    @Test func cornersAreStopsAndTheRunIntoTheEndIsTheLastStep() {
        let analysis = MazeAnalysis(maze: twoCornerMaze(), stepsPerMove: 4)
        let route = analysis.routes[.blue]

        #expect(route?.stops == [
            Route.Stop(step: 1, anchor: .cell(Cell(x: 4, y: 0))),
            Route.Stop(step: 2, anchor: .cell(Cell(x: 4, y: 3))),
        ])
        #expect(route?.totalSteps == 3)
        #expect(route?.cells.count == 10)
    }

    @Test func movesRoundAPartialLastMoveUp() {
        let maze = twoCornerMaze()

        #expect(MazeAnalysis(maze: maze, stepsPerMove: 4).moves(for: .blue) == 1)
        #expect(MazeAnalysis(maze: maze, stepsPerMove: 3).moves(for: .blue) == 1)
        #expect(MazeAnalysis(maze: maze, stepsPerMove: 2).moves(for: .blue) == 2)
        #expect(MazeAnalysis(maze: maze, stepsPerMove: 1).moves(for: .blue) == 3)
    }

    @Test func stopsOnAMoveBoundaryCompleteThatMove() {
        let analysis = MazeAnalysis(maze: twoCornerMaze(), stepsPerMove: 2)
        let stops = analysis.routes[.blue]?.stops ?? []

        #expect(stops.map(analysis.moveCompleted) == [nil, 1])
    }

    @Test func aRoomIsAStopEvenWhenThePathRunsStraightThrough() {
        var maze = Maze(width: 10, height: 10)
        addRoom(&maze, 0, 1, 0, 1, .redStart)
        addRoom(&maze, 3, 0, 4, 2, nil)
        addRoom(&maze, 8, 1, 8, 1, .end)
        path(&maze, (0, 1), (3, 1))
        path(&maze, (4, 1), (8, 1))

        let route = MazeAnalysis(maze: maze, stepsPerMove: 4).routes[.red]

        #expect(steps(route) == [1])
        #expect(route?.stops.first?.anchor == .room(maze.rooms[1]))
        #expect(route?.totalSteps == 2)
        #expect(route?.rooms == [maze.rooms[1]])
    }

    @Test func aRoomIsOneStopHoweverThePathTurnsThroughIt() {
        var maze = Maze(width: 10, height: 10)
        addRoom(&maze, 0, 1, 0, 1, .blueStart)
        addRoom(&maze, 3, 0, 5, 2, nil)
        addRoom(&maze, 4, 6, 4, 6, .end)
        path(&maze, (0, 1), (3, 1))
        path(&maze, (4, 2), (4, 6))

        let route = MazeAnalysis(maze: maze, stepsPerMove: 4).routes[.blue]

        #expect(steps(route) == [1])
        #expect(route?.totalSteps == 2)
    }

    @Test func unfinishedPathIsLabelledAsFarAsItGoesAndFlagsItsDeadEnd() {
        var maze = Maze(width: 10, height: 10)
        addRoom(&maze, 0, 0, 0, 0, .blueStart)
        path(&maze, (0, 0), (4, 0), (4, 3))

        let analysis = MazeAnalysis(maze: maze, stepsPerMove: 4)

        #expect(steps(analysis.routes[.blue]) == [1])
        #expect(analysis.routes[.blue]?.totalSteps == nil)
        #expect(analysis.moves(for: .blue) == nil)
        #expect(analysis.issues.contains(MazeIssue(
            message: "Blue path hits a dead end", cells: [Cell(x: 4, y: 3)], marksCanvas: true
        )))
    }

    @Test func junctionStopsTheWalk() {
        var maze = twoCornerMaze()
        path(&maze, (2, 0), (2, 2))

        let analysis = MazeAnalysis(maze: maze, stepsPerMove: 4)

        #expect(analysis.routes[.blue]?.totalSteps == nil)
        #expect(analysis.issues.contains(MazeIssue(
            message: "Blue path splits at a junction", cells: [Cell(x: 2, y: 0)], marksCanvas: true
        )))
    }

    @Test func missingAndDuplicateMarkersAreReported() {
        var maze = Maze(width: 10, height: 10)
        addRoom(&maze, 0, 0, 0, 0, .blueStart)
        addRoom(&maze, 5, 5, 5, 5, .blueStart)

        let messages = MazeAnalysis(maze: maze, stepsPerMove: 4).issues.map(\.message)

        #expect(messages.contains("2 blue Start rooms"))
        #expect(messages.contains("No red Start room"))
        #expect(messages.contains("No End room"))
    }

    /// Blue takes 3 steps and red takes 2, into a shared End.
    private func sharedEndMaze() -> Maze {
        var maze = twoCornerMaze()
        addRoom(&maze, 8, 9, 8, 9, .redStart)
        path(&maze, (8, 9), (9, 9), (9, 3), (8, 3))
        return maze
    }

    @Test func bothTeamsCanShareAnEnd() {
        let analysis = MazeAnalysis(maze: sharedEndMaze(), stepsPerMove: 4)

        #expect(analysis.routes[.blue]?.totalSteps == 3)
        #expect(analysis.routes[.red]?.totalSteps == 3)
        #expect(analysis.issues.isEmpty)
    }

    @Test func differentStepCountsAreFairWhenTheMoveCountsMatch() {
        var maze = sharedEndMaze()
        // Give blue two extra corners with a detour.
        maze.erase(Cell(x: 2, y: 0))
        path(&maze, (1, 0), (1, 1), (3, 1), (3, 0))

        let fair = MazeAnalysis(maze: maze, stepsPerMove: 4)
        #expect(fair.routes[.blue]?.totalSteps == 7)
        #expect(fair.moves(for: .blue) == 2)
        #expect(fair.moves(for: .red) == 1)
        #expect(fair.issues.map(\.message) == ["Blue takes 2 moves, red takes 1 move"])

        let relaxed = MazeAnalysis(maze: maze, stepsPerMove: 8)
        #expect(relaxed.moves(for: .blue) == relaxed.moves(for: .red))
        #expect(relaxed.issues.isEmpty)
    }

    @Test func strayPathsAndRoomsAreReportedAndEmptyCellsCounted() {
        var maze = twoCornerMaze()
        path(&maze, (0, 8), (2, 8))
        addRoom(&maze, 5, 7, 6, 8, nil)

        let analysis = MazeAnalysis(maze: maze, stepsPerMove: 4)
        let messages = analysis.issues.map(\.message)

        #expect(messages.contains("3 path cells not on a route"))
        #expect(messages.contains("1 room not on a route"))
        #expect(analysis.emptyCellCount == 100 - 12 - 3 - 4)
    }

    @Test func settingsSavedBeforeStepsPerMoveDefaultToFour() throws {
        let settings = try JSONDecoder().decode(MazeDocument.Settings.self, from: Data(#"{"wallThickness":3}"#.utf8))

        #expect(settings.stepsPerMove == 4)
        #expect(settings.wallThickness == 3)
    }
}
