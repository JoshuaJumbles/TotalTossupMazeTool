import Foundation

/// A rectangular open space. Its cells are carved and fully connected inside the maze;
/// paths join it through connections across its perimeter.
struct Room: Codable, Equatable {
    /// What a room means to the game. An End takes no team: it belongs to whichever
    /// path reaches it, and both teams may share one.
    enum Marker: String, Codable, CaseIterable {
        case blueStart, redStart, end

        /// The marker a tap moves to: none, blue start, red start, end, then none again.
        static func next(after marker: Marker?) -> Marker? {
            guard let marker else { return allCases.first }
            let index = allCases.firstIndex(of: marker)! + 1
            return index < allCases.count ? allCases[index] : nil
        }
    }

    var x: Int
    var y: Int
    var width: Int
    var height: Int
    var marker: Marker?

    /// The room spanning two opposite corner cells, in either order.
    init(from a: Cell, to b: Cell) {
        x = min(a.x, b.x)
        y = min(a.y, b.y)
        width = abs(a.x - b.x) + 1
        height = abs(a.y - b.y) + 1
    }

    var cells: [Cell] {
        (y..<y + height).flatMap { row in
            (x..<x + width).map { Cell(x: $0, y: row) }
        }
    }

    func contains(_ cell: Cell) -> Bool {
        (x..<x + width).contains(cell.x) && (y..<y + height).contains(cell.y)
    }

    func overlaps(_ other: Room) -> Bool {
        x < other.x + other.width && other.x < x + width
            && y < other.y + other.height && other.y < y + height
    }
}
