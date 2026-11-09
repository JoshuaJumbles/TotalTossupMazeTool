import Foundation
import Observation

/// Loads and saves mazes as one JSON file each, named by document id.
@MainActor
@Observable
final class DocumentStore {
    /// Most recently modified first.
    private(set) var documents: [MazeDocument] = []

    private let directory: URL

    nonisolated static var defaultDirectory: URL {
        URL.documentsDirectory.appending(path: "Mazes", directoryHint: .isDirectory)
    }

    init(directory: URL = DocumentStore.defaultDirectory) {
        self.directory = directory
        reload()
    }

    func document(id: MazeDocument.ID) -> MazeDocument? {
        documents.first { $0.id == id }
    }

    /// Re-reads every file in the directory. Files that fail to decode are skipped.
    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        documents = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Self.decoder.decode(MazeDocument.self, from: Data(contentsOf: $0)) }
        sort()
    }

    @discardableResult
    func create(name: String, width: Int, height: Int) throws -> MazeDocument {
        let document = MazeDocument(name: name, width: width, height: height)
        try write(document)
        return document
    }

    @discardableResult
    func duplicate(_ source: MazeDocument) throws -> MazeDocument {
        var copy = source
        copy.id = UUID()
        copy.name = "\(source.name) copy"
        copy.createdAt = Date()
        copy.modifiedAt = copy.createdAt
        try write(copy)
        return copy
    }

    func rename(_ document: MazeDocument, to name: String) throws {
        var renamed = document
        renamed.name = MazeDocument.cleaned(name)
        try save(renamed)
    }

    /// Writes the document and stamps it as modified now.
    func save(_ document: MazeDocument) throws {
        var saved = document
        saved.modifiedAt = Date()
        try write(saved)
    }

    func delete(_ document: MazeDocument) throws {
        let url = fileURL(for: document.id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        documents.removeAll { $0.id == document.id }
    }

    private func write(_ document: MazeDocument) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(document).write(to: fileURL(for: document.id), options: .atomic)
        documents.removeAll { $0.id == document.id }
        documents.append(document)
        sort()
    }

    private func sort() {
        documents.sort { $0.modifiedAt > $1.modifiedAt }
    }

    private func fileURL(for id: MazeDocument.ID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }

    // Dates use the default numeric strategy: ISO 8601 drops sub-second precision,
    // which breaks modified-date ordering after a reload.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()
}
