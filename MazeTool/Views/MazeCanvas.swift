import SwiftUI

/// Draws a maze scaled to fit: uncarved cells shaded, carved cells clear, walls on every
/// carved edge that has no connection.
struct MazeCanvas: View {
    let maze: Maze
    var wallThickness: CGFloat = 2
    var showsGrid = true

    var body: some View {
        Canvas { context, size in
            let geometry = GridGeometry(columns: maze.width, rows: maze.height, size: size)
            var floor = Path()
            var walls = Path()
            for y in 0..<maze.height {
                for x in 0..<maze.width {
                    let cell = Cell(x: x, y: y)
                    guard maze.isCarved(cell) else { continue }
                    let rect = geometry.rect(for: cell)
                    floor.addRect(rect)
                    for direction in Direction.allCases where !maze.isOpen(cell, cell.neighbor(direction)) {
                        let (start, end) = Self.side(direction, of: rect)
                        walls.move(to: start)
                        walls.addLine(to: end)
                    }
                }
            }

            context.fill(Path(geometry.frame), with: .color(Color(.systemGray5)))
            context.fill(floor, with: .color(Color(.systemBackground)))
            if showsGrid {
                context.stroke(Self.gridLines(geometry), with: .color(.secondary.opacity(0.35)), lineWidth: 0.5)
            }
            context.stroke(
                walls, with: .color(.primary),
                style: StrokeStyle(lineWidth: wallThickness, lineCap: .square)
            )
            context.stroke(Path(geometry.frame), with: .color(.primary), lineWidth: 1)
        }
    }

    private static func side(_ direction: Direction, of rect: CGRect) -> (CGPoint, CGPoint) {
        switch direction {
        case .up: (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY))
        case .down: (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY))
        case .left: (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY))
        case .right: (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY))
        }
    }

    private static func gridLines(_ geometry: GridGeometry) -> Path {
        var lines = Path()
        let frame = geometry.frame
        for column in 1..<max(geometry.columns, 1) {
            let x = frame.minX + CGFloat(column) * geometry.cellSize
            lines.move(to: CGPoint(x: x, y: frame.minY))
            lines.addLine(to: CGPoint(x: x, y: frame.maxY))
        }
        for row in 1..<max(geometry.rows, 1) {
            let y = frame.minY + CGFloat(row) * geometry.cellSize
            lines.move(to: CGPoint(x: frame.minX, y: y))
            lines.addLine(to: CGPoint(x: frame.maxX, y: y))
        }
        return lines
    }
}

#Preview {
    var maze = Maze(width: 8, height: 12)
    maze.carvePath(from: Cell(x: 1, y: 1), to: Cell(x: 6, y: 1))
    maze.carvePath(from: Cell(x: 6, y: 1), to: Cell(x: 6, y: 9))
    return MazeCanvas(maze: maze)
        .padding()
}
