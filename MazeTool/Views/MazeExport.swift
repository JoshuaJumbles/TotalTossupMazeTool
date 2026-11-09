import SwiftUI

/// Renders a maze to transparent PNGs. Exports always use the light look, whatever the
/// app's appearance: black walls with nothing behind them.
@MainActor
enum MazeExport {
    enum Style: String, CaseIterable, Identifiable {
        /// Walls only, as in the editor's preview.
        case maze
        /// Walls plus team colour, step labels, move badges and room markers.
        case overlay

        var id: Self { self }

        var title: String {
            switch self {
            case .maze: "Maze"
            case .overlay: "With overlays"
            }
        }

        var fileSuffix: String {
            switch self {
            case .maze: "maze"
            case .overlay: "overlay"
            }
        }
    }

    /// A cell's side in points, close to its size on screen so wall thickness keeps its proportion.
    static let cellPoints: CGFloat = 24
    /// Pixels per point: 96 pixels per cell, so a 16 × 24 maze is about 1540 × 2310.
    static let scale: CGFloat = 4

    /// The image's size in pixels, including the margin that keeps edge walls whole.
    static func pixelSize(of document: MazeDocument) -> CGSize {
        let inset = inset(for: document)
        return CGSize(
            width: ((CGFloat(document.width) * cellPoints + inset * 2) * scale).rounded(),
            height: ((CGFloat(document.height) * cellPoints + inset * 2) * scale).rounded()
        )
    }

    static func image(of document: MazeDocument, style: Style) -> UIImage? {
        let inset = inset(for: document)
        let canvas = MazeCanvas(
            maze: document.maze,
            wallThickness: document.settings.wallThickness,
            showsGrid: false,
            isPreview: style == .maze,
            showsBackdrop: false,
            ink: .black,
            inset: inset,
            analysis: style == .overlay
                ? MazeAnalysis(maze: document.maze, stepsPerMove: document.settings.stepsPerMove)
                : nil
        )
        .frame(
            width: CGFloat(document.width) * cellPoints + inset * 2,
            height: CGFloat(document.height) * cellPoints + inset * 2
        )
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: canvas)
        renderer.scale = scale
        renderer.isOpaque = false
        return renderer.uiImage
    }

    /// Writes the PNG to a temporary file named after the maze, ready to share.
    static func writePNG(of document: MazeDocument, style: Style) throws -> URL {
        guard let data = image(of: document, style: style)?.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        let directory = URL.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(fileName(for: document.name))-\(style.fileSuffix).png")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The maze name with anything awkward in a file name replaced by a dash.
    static func fileName(for name: String) -> String {
        let cleaned = name
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: " -_")).inverted)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "maze" : cleaned
    }

    private static func inset(for document: MazeDocument) -> CGFloat {
        (document.settings.wallThickness / 2).rounded(.up)
    }
}
