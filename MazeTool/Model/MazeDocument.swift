import Foundation

/// One maze file. Maze content (cells, connections, rooms) is added with the editor.
struct MazeDocument: Codable, Identifiable, Equatable {
    static let currentVersion = 1
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
    var width: Int
    var height: Int
    var createdAt = Date()
    var modifiedAt = Date()
    var settings = Settings()

    init(name: String, width: Int, height: Int) {
        self.name = MazeDocument.cleaned(name)
        self.width = MazeDocument.clamped(width)
        self.height = MazeDocument.clamped(height)
    }

    static func cleaned(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? untitledName : trimmed
    }

    static func clamped(_ size: Int) -> Int {
        min(max(size, sizeRange.lowerBound), sizeRange.upperBound)
    }
}
