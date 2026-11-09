import Foundation

struct Cell: Hashable {
    var x: Int
    var y: Int

    func neighbor(_ direction: Direction) -> Cell {
        Cell(x: x + direction.dx, y: y + direction.dy)
    }
}

enum Direction: CaseIterable {
    case up, down, left, right

    var dx: Int {
        switch self {
        case .left: -1
        case .right: 1
        case .up, .down: 0
        }
    }

    var dy: Int {
        switch self {
        case .up: -1
        case .down: 1
        case .left, .right: 0
        }
    }
}

/// Grid maze content. A carved cell is open floor; connections live on the edges
/// between adjacent cells, and a wall is any edge of a carved cell with no connection.
struct Maze: Equatable {
    let width: Int
    let height: Int

    private var carved: [Bool]
    /// Connection from each cell to its right-hand neighbour, row-major. The last column is unused.
    private var openRight: [Bool]
    /// Connection from each cell to the neighbour below, row-major. The last row is unused.
    private var openDown: [Bool]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        carved = Array(repeating: false, count: width * height)
        openRight = carved
        openDown = carved
    }

    var isEmpty: Bool { !carved.contains(true) }

    func contains(_ cell: Cell) -> Bool {
        (0..<width).contains(cell.x) && (0..<height).contains(cell.y)
    }

    func isCarved(_ cell: Cell) -> Bool {
        contains(cell) && carved[index(cell)]
    }

    /// Whether two adjacent cells are connected. False for cells that aren't neighbours.
    func isOpen(_ a: Cell, _ b: Cell) -> Bool {
        guard let edge = edge(a, b) else { return false }
        return edge.horizontal ? openRight[edge.index] : openDown[edge.index]
    }

    mutating func carve(_ cell: Cell) {
        guard contains(cell) else { return }
        carved[index(cell)] = true
    }

    /// Carves both cells and opens the edge between them. Ignored unless the cells are neighbours.
    mutating func connect(_ a: Cell, _ b: Cell) {
        guard let edge = edge(a, b) else { return }
        carved[index(a)] = true
        carved[index(b)] = true
        setOpen(true, edge)
    }

    /// Fills the cell back in and closes its connections.
    mutating func erase(_ cell: Cell) {
        guard contains(cell) else { return }
        carved[index(cell)] = false
        for direction in Direction.allCases {
            if let edge = edge(cell, cell.neighbor(direction)) {
                setOpen(false, edge)
            }
        }
    }

    /// Carves a connected corridor from `start` to `end`, one cardinal step at a time.
    mutating func carvePath(from start: Cell, to end: Cell) {
        carve(start)
        var current = start
        for step in Maze.steps(from: start, to: end) {
            connect(current, step)
            current = step
        }
    }

    /// The cells visited walking from `start` to `end` in cardinal steps, excluding `start`.
    /// A diagonal becomes a staircase that follows the straight line between the two cells.
    static func steps(from start: Cell, to end: Cell) -> [Cell] {
        var steps: [Cell] = []
        var current = start
        while current != end {
            let dx = end.x - current.x
            let dy = end.y - current.y
            if abs(dx) >= abs(dy) {
                current.x += dx.signum()
            } else {
                current.y += dy.signum()
            }
            steps.append(current)
        }
        return steps
    }

    private struct Edge {
        var horizontal: Bool
        var index: Int
    }

    private func index(_ cell: Cell) -> Int {
        cell.y * width + cell.x
    }

    private func edge(_ a: Cell, _ b: Cell) -> Edge? {
        guard contains(a), contains(b) else { return nil }
        switch (b.x - a.x, b.y - a.y) {
        case (1, 0): return Edge(horizontal: true, index: index(a))
        case (-1, 0): return Edge(horizontal: true, index: index(b))
        case (0, 1): return Edge(horizontal: false, index: index(a))
        case (0, -1): return Edge(horizontal: false, index: index(b))
        default: return nil
        }
    }

    private mutating func setOpen(_ isOpen: Bool, _ edge: Edge) {
        if edge.horizontal {
            openRight[edge.index] = isOpen
        } else {
            openDown[edge.index] = isOpen
        }
    }
}

/// Encoded as one string per row ("#" set, "." clear) so saved files stay small and readable.
extension Maze: Codable {
    private enum CodingKeys: String, CodingKey {
        case width, height, cells, right, down
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            width: try container.decode(Int.self, forKey: .width),
            height: try container.decode(Int.self, forKey: .height)
        )
        carved = try flags(in: container, forKey: .cells)
        openRight = try flags(in: container, forKey: .right)
        openDown = try flags(in: container, forKey: .down)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(rows(carved), forKey: .cells)
        try container.encode(rows(openRight), forKey: .right)
        try container.encode(rows(openDown), forKey: .down)
    }

    private func rows(_ flags: [Bool]) -> [String] {
        (0..<height).map { y in
            String(flags[y * width..<(y + 1) * width].map { $0 ? "#" : "." })
        }
    }

    private func flags(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> [Bool] {
        let rows = try container.decode([String].self, forKey: key)
        guard rows.count == height, rows.allSatisfy({ $0.count == width }) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: container,
                debugDescription: "Expected \(height) rows of \(width) characters."
            )
        }
        return rows.flatMap { $0.map { $0 == "#" } }
    }
}
