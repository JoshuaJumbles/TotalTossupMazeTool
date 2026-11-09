import SwiftUI

/// An empty grid of the given size, scaled to fit the space it is given.
struct GridPreview: View {
    let width: Int
    let height: Int
    var lineWidth: CGFloat = 0.5

    var body: some View {
        Canvas { context, size in
            let cell = min(size.width / CGFloat(width), size.height / CGFloat(height))
            let grid = CGSize(width: cell * CGFloat(width), height: cell * CGFloat(height))
            let origin = CGPoint(x: (size.width - grid.width) / 2, y: (size.height - grid.height) / 2)

            var lines = Path()
            for column in 1..<max(width, 1) {
                let x = origin.x + CGFloat(column) * cell
                lines.move(to: CGPoint(x: x, y: origin.y))
                lines.addLine(to: CGPoint(x: x, y: origin.y + grid.height))
            }
            for row in 1..<max(height, 1) {
                let y = origin.y + CGFloat(row) * cell
                lines.move(to: CGPoint(x: origin.x, y: y))
                lines.addLine(to: CGPoint(x: origin.x + grid.width, y: y))
            }
            context.stroke(lines, with: .color(.secondary.opacity(0.5)), lineWidth: lineWidth)
            context.stroke(Path(CGRect(origin: origin, size: grid)), with: .color(.primary), lineWidth: lineWidth * 2)
        }
        .aspectRatio(CGFloat(width) / CGFloat(height), contentMode: .fit)
    }
}

#Preview {
    GridPreview(width: MazeDocument.defaultWidth, height: MazeDocument.defaultHeight)
        .padding()
}
