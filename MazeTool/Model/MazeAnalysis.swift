import Foundation

enum Team: String, CaseIterable {
    case blue, red

    var name: String { rawValue.capitalized }

    var startMarker: Room.Marker {
        switch self {
        case .blue: .blueStart
        case .red: .redStart
        }
    }
}

/// The path walked from one team's Start, as far as it can be followed unambiguously.
struct Route: Equatable {
    /// A place a player can stop: a corner of the path, or a room along it.
    struct Stop: Equatable {
        enum Anchor: Equatable {
            case cell(Cell)
            case room(Room)
        }

        /// Steps taken from the Start to reach this stop.
        var step: Int
        var anchor: Anchor
    }

    let team: Team
    /// Corridor cells on the route, in walking order.
    var cells: [Cell] = []
    /// Rooms passed through between the Start and the End.
    var rooms: [Room] = []
    var stops: [Stop] = []
    /// Steps from Start to End, counting the final run into the End. Nil until the route reaches an End.
    var totalSteps: Int?

    /// Steps counted so far, whether or not the route is finished.
    var stepsWalked: Int { totalSteps ?? stops.last?.step ?? 0 }
}

struct MazeIssue: Hashable {
    var message: String
    /// Where the problem is, if it has a place.
    var cells: [Cell] = []
    /// Whether the editor always rings these cells, rather than only when the issue is selected.
    var marksCanvas = false
}

/// Everything derived from a maze for the editor overlays: each team's route, its stops
/// and step counts, and the problems that keep the maze from being a finished race.
///
/// A step runs from one stop to the next. Every corner is a stop, every room along the
/// way is a stop even when the path runs straight through, and the run into the End is
/// the last step. A move is a fixed number of steps; a fair maze takes both teams the
/// same number of moves.
struct MazeAnalysis {
    let stepsPerMove: Int
    private(set) var routes: [Team: Route] = [:]
    private(set) var issues: [MazeIssue] = []
    /// Cells that are neither path nor room. Informational: leaving dead space is allowed.
    private(set) var emptyCellCount = 0

    init(maze: Maze, stepsPerMove: Int) {
        self.stepsPerMove = max(stepsPerMove, 1)

        for team in Team.allCases {
            let starts = maze.rooms.filter { $0.marker == team.startMarker }
            switch starts.count {
            case 0:
                issues.append(MazeIssue(message: "No \(team.rawValue) Start room"))
            case 1:
                routes[team] = walk(team, from: starts[0], in: maze)
            default:
                issues.append(MazeIssue(
                    message: "\(starts.count) \(team.rawValue) Start rooms",
                    cells: starts.flatMap(\.cells)
                ))
            }
        }
        if !maze.rooms.contains(where: { $0.marker == .end }) {
            issues.append(MazeIssue(message: "No End room"))
        }

        let routeCells = Set(routes.values.flatMap(\.cells))
        var strayCells: [Cell] = []
        for y in 0..<maze.height {
            for x in 0..<maze.width {
                let cell = Cell(x: x, y: y)
                if !maze.isCarved(cell) {
                    emptyCellCount += 1
                } else if maze.room(at: cell) == nil, !routeCells.contains(cell) {
                    strayCells.append(cell)
                }
            }
        }
        if !strayCells.isEmpty {
            issues.append(MazeIssue(
                message: "\(Self.count(strayCells.count, "path cell")) not on a route",
                cells: strayCells
            ))
        }
        let routeRooms = routes.values.flatMap(\.rooms)
        let strayRooms = maze.rooms.filter { $0.marker == nil && !routeRooms.contains($0) }
        if !strayRooms.isEmpty {
            issues.append(MazeIssue(
                message: "\(Self.count(strayRooms.count, "room")) not on a route",
                cells: strayRooms.flatMap(\.cells)
            ))
        }

        if let blue = moves(for: .blue), let red = moves(for: .red), blue != red {
            issues.append(MazeIssue(
                message: "Blue takes \(Self.count(blue, "move")), red takes \(Self.count(red, "move"))"
            ))
        }
    }

    /// Moves needed to reach the End, rounding a partial last move up. Nil until the route is finished.
    func moves(for team: Team) -> Int? {
        routes[team]?.totalSteps.map { ($0 + stepsPerMove - 1) / stepsPerMove }
    }

    /// The move a stop completes, if it falls exactly on a move boundary.
    func moveCompleted(at stop: Route.Stop) -> Int? {
        stop.step.isMultiple(of: stepsPerMove) ? stop.step / stepsPerMove : nil
    }

    /// Follows the path out of `start` until it reaches an End or can't continue, recording
    /// the reason as an issue when it stops short.
    private mutating func walk(_ team: Team, from start: Room, in maze: Maze) -> Route {
        var route = Route(team: team)
        func stopped(_ reason: String, at cell: Cell) -> Route {
            issues.append(MazeIssue(message: "\(team.name) \(reason)", cells: [cell], marksCanvas: true))
            return route
        }

        let exits = Self.doorways(of: start, in: maze)
        guard exits.count == 1 else {
            issues.append(MazeIssue(
                message: exits.isEmpty
                    ? "\(team.name) Start has no exit"
                    : "\(team.name) Start has \(exits.count) exits",
                cells: exits.map(\.inside)
            ))
            return route
        }

        var previous = exits[0].inside
        var current = exits[0].outside
        var steps = 0
        var visited: Set<Cell> = []
        while true {
            if let room = maze.room(at: current) {
                steps += 1
                if room.marker == .end {
                    route.totalSteps = steps
                    return route
                }
                guard room.marker == nil else { return stopped("path runs into a Start room", at: current) }
                guard !route.rooms.contains(room) else { return stopped("path loops back on itself", at: current) }
                route.rooms.append(room)
                route.stops.append(Route.Stop(step: steps, anchor: .room(room)))

                let entrance = (inside: current, outside: previous)
                let onward = Self.doorways(of: room, in: maze).filter { $0 != entrance }
                guard onward.count == 1 else {
                    return stopped(
                        onward.isEmpty ? "path ends in a room that isn't an End" : "path reaches a room with \(onward.count + 1) doorways",
                        at: current
                    )
                }
                previous = onward[0].inside
                current = onward[0].outside
                continue
            }

            guard visited.insert(current).inserted else { return stopped("path loops back on itself", at: current) }
            route.cells.append(current)
            let onward = Direction.allCases
                .map(current.neighbor)
                .filter { $0 != previous && maze.isOpen(current, $0) }
            guard onward.count == 1 else {
                return stopped(onward.isEmpty ? "path hits a dead end" : "path splits at a junction", at: current)
            }
            let next = onward[0]
            let turns = (next.x - current.x, next.y - current.y) != (current.x - previous.x, current.y - previous.y)
            if turns {
                steps += 1
                route.stops.append(Route.Stop(step: steps, anchor: .cell(current)))
            }
            previous = current
            current = next
        }
    }

    /// Open connections across the room's perimeter, as the room cell and the cell outside it.
    private static func doorways(of room: Room, in maze: Maze) -> [(inside: Cell, outside: Cell)] {
        room.cells.flatMap { cell in
            Direction.allCases
                .map(cell.neighbor)
                .filter { !room.contains($0) && maze.isOpen(cell, $0) }
                .map { (inside: cell, outside: $0) }
        }
    }

    private static func count(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}
