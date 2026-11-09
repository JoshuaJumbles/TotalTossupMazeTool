import Foundation

/// One maze file: the maze itself plus its name, dates and per-document settings.
struct MazeDocument: Codable, Identifiable, Equatable {
    static let currentVersion = 2
    static let sizeRange = 2...40
    static let defaultWidth = 16
    static let defaultHeight = 24
    static let untitledName = "Untitled maze"

    struct Settings: Codable, Equatable {
        var wallThickness: Double = 2
    }

    var version = MazeDocument.currentVersion
    var id = UUID()
    var name: String
    var maze: Maze
    var createdAt = Date()
    var modifiedAt = Date()
    var settings = Settings()

    var width: Int { maze.width }
    var height: Int { maze.height }

    init(name: String, width: Int, height: Int) {
        self.name = MazeDocument.cleaned(name)
        self.maze = Maze(width: MazeDocument.clamped(width), height: MazeDocument.clamped(height))
    }

    static func cleaned(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? untitledName : trimmed
    }

    static func clamped(_ size: Int) -> Int {
        min(max(size, sizeRange.lowerBound), sizeRange.upperBound)
    }
}
