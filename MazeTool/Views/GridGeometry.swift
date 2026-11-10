import CoreGraphics

/// Maps between grid cells and points for a grid centred in, and scaled to fit, a given size.
struct GridGeometry {
    /// The cell size that wall thickness is measured against: a 16 × 24 maze on an iPhone.
    /// Walls are drawn in proportion, so a maze looks the same at any size.
    static let referenceCellSize: CGFloat = 24

    /// The grid lines that divide `count` cells into blocks two cells wide, counted inwards
    /// from both edges. Blocks always sit flush against the edges, where a path most needs
    /// room to turn back; any cells left over (one, or three, for an odd count) end up
    /// undivided in the middle.
    static func blockLines(count: Int) -> [Int] {
        guard count >= 4 else { return [] }
        let fromNearEdge = Array(stride(from: 2, through: count / 2, by: 2))
        return Set(fromNearEdge + fromNearEdge.map { count - $0 }).sorted()
    }

    let columns: Int
    let rows: Int
    let cellSize: CGFloat
    let frame: CGRect

    init(columns: Int, rows: Int, size: CGSize) {
        self.columns = columns
        self.rows = rows
        cellSize = max(min(size.width / CGFloat(columns), size.height / CGFloat(rows)), 0)
        let gridSize = CGSize(width: cellSize * CGFloat(columns), height: cellSize * CGFloat(rows))
        frame = CGRect(
            x: (size.width - gridSize.width) / 2,
            y: (size.height - gridSize.height) / 2,
            width: gridSize.width,
            height: gridSize.height
        )
    }

    func rect(for cell: Cell) -> CGRect {
        CGRect(
            x: frame.minX + CGFloat(cell.x) * cellSize,
            y: frame.minY + CGFloat(cell.y) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    func rect(for room: Room) -> CGRect {
        CGRect(
            x: frame.minX + CGFloat(room.x) * cellSize,
            y: frame.minY + CGFloat(room.y) * cellSize,
            width: CGFloat(room.width) * cellSize,
            height: CGFloat(room.height) * cellSize
        )
    }

    /// The interior grid vertex closest to `point`. Vertex (x, y) is the top-left corner of
    /// cell (x, y); vertices on the outer border are excluded, so every one has four cells around it.
    func nearestVertex(to point: CGPoint) -> Cell {
        guard cellSize > 0 else { return Cell(x: 1, y: 1) }
        let x = Int(((point.x - frame.minX) / cellSize).rounded())
        let y = Int(((point.y - frame.minY) / cellSize).rounded())
        return Cell(x: min(max(x, 1), max(columns - 1, 1)), y: min(max(y, 1), max(rows - 1, 1)))
    }

    /// The cell under `point`, or the closest edge cell when the point is outside the grid.
    func nearestCell(to point: CGPoint) -> Cell {
        guard cellSize > 0 else { return Cell(x: 0, y: 0) }
        let x = Int(((point.x - frame.minX) / cellSize).rounded(.down))
        let y = Int(((point.y - frame.minY) / cellSize).rounded(.down))
        return Cell(x: min(max(x, 0), columns - 1), y: min(max(y, 0), rows - 1))
    }
}
