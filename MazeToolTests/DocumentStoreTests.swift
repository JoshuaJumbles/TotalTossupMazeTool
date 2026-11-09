import Foundation
import Testing
@testable import MazeTool

@MainActor
struct DocumentStoreTests {
    private let directory = URL.temporaryDirectory.appending(path: "MazeToolTests-\(UUID().uuidString)")

    @Test func createdDocumentSurvivesReload() throws {
        let created = try DocumentStore(directory: directory).create(name: "Harbor", width: 16, height: 24)

        let reloaded = DocumentStore(directory: directory).documents

        #expect(reloaded.count == 1)
        #expect(reloaded.first?.id == created.id)
        #expect(reloaded.first?.name == "Harbor")
        #expect(reloaded.first?.width == 16)
        #expect(reloaded.first?.height == 24)
        #expect(reloaded.first?.settings == created.settings)
    }

    @Test func blankNameAndOutOfRangeSizeAreNormalised() throws {
        let document = try DocumentStore(directory: directory).create(name: "  ", width: 0, height: 999)

        #expect(document.name == MazeDocument.untitledName)
        #expect(document.width == MazeDocument.sizeRange.lowerBound)
        #expect(document.height == MazeDocument.sizeRange.upperBound)
    }

    @Test func duplicateIsAnIndependentCopy() throws {
        let store = DocumentStore(directory: directory)
        let original = try store.create(name: "Harbor", width: 10, height: 12)

        let copy = try store.duplicate(original)
        try store.delete(original)

        let remaining = DocumentStore(directory: directory).documents
        #expect(copy.id != original.id)
        #expect(remaining.map(\.id) == [copy.id])
        #expect(remaining.first?.name == "Harbor copy")
        #expect(remaining.first?.width == 10)
        #expect(remaining.first?.height == 12)
    }

    @Test func renamePersistsAndMovesDocumentToTop() throws {
        let store = DocumentStore(directory: directory)
        let first = try store.create(name: "First", width: 4, height: 4)
        try store.create(name: "Second", width: 4, height: 4)

        try store.rename(first, to: "Renamed")

        let reloaded = DocumentStore(directory: directory).documents
        #expect(reloaded.first?.id == first.id)
        #expect(reloaded.first?.name == "Renamed")
        #expect(reloaded.count == 2)
    }

    @Test func deleteRemovesTheFile() throws {
        let store = DocumentStore(directory: directory)
        let document = try store.create(name: "Gone", width: 4, height: 4)

        try store.delete(document)

        #expect(store.documents.isEmpty)
        #expect(DocumentStore(directory: directory).documents.isEmpty)
    }

    @Test func unreadableFilesAreSkipped() throws {
        let store = DocumentStore(directory: directory)
        try store.create(name: "Good", width: 4, height: 4)
        try Data("not json".utf8).write(to: directory.appending(path: "broken.json"))

        store.reload()

        #expect(store.documents.map(\.name) == ["Good"])
    }
}
