import Foundation

/// An editing aid: while on, every stroke is repeated as its mirror image about the grid centre.
/// It is editor state, not part of the maze, so symmetric and freehand strokes can be mixed.
enum Symmetry: String, CaseIterable, Identifiable {
    case off, leftRight, topBottom, rotate

    var id: Self { self }

    /// The mirror image of a point on a grid whose coordinates run 0...maxX and 0...maxY,
    /// or nil when symmetry is off. Cells use the last cell index as the maximum; vertices
    /// use the grid's width and height.
    func reflect(_ point: Cell, maxX: Int, maxY: Int) -> Cell? {
        switch self {
        case .off: nil
        case .leftRight: Cell(x: maxX - point.x, y: point.y)
        case .topBottom: Cell(x: point.x, y: maxY - point.y)
        case .rotate: Cell(x: maxX - point.x, y: maxY - point.y)
        }
    }
}
