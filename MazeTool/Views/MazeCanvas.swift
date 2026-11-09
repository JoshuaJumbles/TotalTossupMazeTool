import SwiftUI

/// Draws a maze scaled to fit: uncarved cells shaded, carved cells clear, walls on every
/// carved edge that has no connection.
struct MazeCanvas: View {
    let maze: Maze
    var wallThickness: CGFloat = 2
    var showsGrid = true
    /// Draws only the walls, in the foreground colour, with nothing behind them. Uncarved cells
    /// are left as blank as open space. Hides all editor overlays.
    var isPreview = false
    /// Fills behind the maze: shaded uncarved cells, clear floor and the outer border. Off for
    /// export, where everything but the drawing itself stays transparent.
    var showsBackdrop = true
    /// The colour of walls and marker letters. Export pins it to black whatever the appearance.
    var ink = Color.primary
    /// Space kept clear around the grid, so walls on its edge aren't cut in half.
    var inset: CGFloat = 0
    /// Zoom and pan. The maze is redrawn at the zoomed size, so it stays sharp.
    var viewport = Viewport()
    /// Rooms being dragged out, drawn as dashed outlines over the maze.
    var roomPreviews: [Room] = []
    var canPlaceRoomPreview = true
    /// Editor overlays: team colour along each route, stop labels and issue rings. Nil draws the bare maze.
    var analysis: MazeAnalysis?
    var highlightedIssue: MazeIssue?
    /// Draws the mirror axis, or the pivot for a rotation, while symmetry is on.
    var symmetry = Symmetry.off

    var body: some View {
        Canvas { context, size in
            var context = context
            context.translateBy(x: inset, y: inset)
            context.translateBy(x: viewport.offset.x, y: viewport.offset.y)
            let size = viewport.contentSize(in: CGSize(width: size.width - inset * 2, height: size.height - inset * 2))
            // Walls keep their proportion to the cells as the maze is zoomed.
            let wallThickness = wallThickness * viewport.zoom
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

            if isPreview {
                context.stroke(
                    walls, with: .color(ink),
                    style: StrokeStyle(lineWidth: wallThickness, lineCap: .square)
                )
                return
            }
            if showsBackdrop {
                context.fill(Path(geometry.frame), with: .color(Color(.systemGray5)))
                context.fill(floor, with: .color(Color(.systemBackground)))
            }
            for room in maze.rooms {
                Self.draw(room, in: geometry.rect(for: room), cellSize: geometry.cellSize, ink: ink, context: context)
            }
            for route in analysis?.routes.values.map({ $0 }) ?? [] {
                var tinted = Path()
                route.cells.forEach { tinted.addRect(geometry.rect(for: $0)) }
                route.rooms.forEach { tinted.addRect(geometry.rect(for: $0)) }
                context.fill(tinted, with: .color(route.team.color.opacity(0.2)))
            }
            if showsGrid {
                var lines = Self.gridLines(geometry)
                // With no backdrop there is no border, so the grid closes its own outer edge.
                if !showsBackdrop {
                    lines.addRect(geometry.frame)
                }
                context.stroke(lines, with: .color(.secondary.opacity(0.35)), lineWidth: 0.5)
            }
            context.stroke(
                walls, with: .color(ink),
                style: StrokeStyle(lineWidth: wallThickness, lineCap: .square)
            )
            if showsBackdrop {
                context.stroke(Path(geometry.frame), with: .color(ink), lineWidth: 1)
            }

            if let analysis {
                for route in analysis.routes.values {
                    for stop in route.stops {
                        Self.draw(stop, of: route.team, completing: analysis.moveCompleted(at: stop), geometry: geometry, context: context)
                    }
                }
                let ringed = analysis.issues.filter(\.marksCanvas).flatMap(\.cells) + (highlightedIssue?.cells ?? [])
                var rings = Path()
                for cell in ringed {
                    rings.addRoundedRect(in: geometry.rect(for: cell).insetBy(dx: 2, dy: 2), cornerSize: CGSize(width: 4, height: 4))
                }
                context.stroke(rings, with: .color(.orange), lineWidth: 2.5)
            }

            Self.drawGuide(for: symmetry, in: geometry.frame, context: context)

            for roomPreview in roomPreviews {
                let outline = Path(geometry.rect(for: roomPreview))
                let color: Color = canPlaceRoomPreview ? .accentColor : .red
                context.fill(outline, with: .color(color.opacity(0.2)))
                context.stroke(outline, with: .color(color), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
    }

    private static func drawGuide(for symmetry: Symmetry, in frame: CGRect, context: GraphicsContext) {
        var axis = Path()
        switch symmetry {
        case .off:
            return
        case .leftRight:
            axis.move(to: CGPoint(x: frame.midX, y: frame.minY))
            axis.addLine(to: CGPoint(x: frame.midX, y: frame.maxY))
        case .topBottom:
            axis.move(to: CGPoint(x: frame.minX, y: frame.midY))
            axis.addLine(to: CGPoint(x: frame.maxX, y: frame.midY))
        case .rotate:
            // A hollow ring, so a marker label in a room at the centre stays readable.
            let pivot = CGRect(x: frame.midX - 10, y: frame.midY - 10, width: 20, height: 20)
            context.stroke(Path(ellipseIn: pivot), with: .color(.purple), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
        context.stroke(axis, with: .color(.purple), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
    }

    /// Tints the room and, for a marked room, labels it S or E.
    private static func draw(_ room: Room, in rect: CGRect, cellSize: CGFloat, ink: Color, context: GraphicsContext) {
        let (tint, label): (Color, String?) = switch room.marker {
        case .blueStart: (.blue, "S")
        case .redStart: (.red, "S")
        case .end: (.yellow, "E")
        case nil: (.secondary, nil)
        }
        context.fill(Path(rect), with: .color(tint.opacity(room.marker == nil ? 0.12 : 0.3)))
        guard let label else { return }
        let fontSize = min(min(rect.width, rect.height) * 0.7, cellSize * 1.5)
        context.draw(
            Text(label).font(.system(size: fontSize, weight: .bold)).foregroundStyle(ink),
            at: CGPoint(x: rect.midX, y: rect.midY)
        )
    }

    /// Labels a stop with its step number in the team colour. A stop that completes a move
    /// gets a filled badge holding the move number instead.
    private static func draw(
        _ stop: Route.Stop, of team: Team, completing move: Int?,
        geometry: GridGeometry, context: GraphicsContext
    ) {
        let rect = switch stop.anchor {
        case .cell(let cell): geometry.rect(for: cell)
        case .room(let room): geometry.rect(for: room)
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let fontSize = geometry.cellSize * 0.55
        if let move {
            let radius = geometry.cellSize * 0.42
            let badge = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: badge), with: .color(team.color))
            context.draw(
                Text("\(move)").font(.system(size: fontSize, weight: .bold)).foregroundStyle(.white),
                at: center
            )
        } else {
            context.draw(
                Text("\(stop.step)").font(.system(size: fontSize, weight: .semibold)).foregroundStyle(team.color),
                at: center
            )
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
