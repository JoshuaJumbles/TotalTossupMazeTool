import Foundation
import Testing
@testable import MazeTool

struct RoomTests {
    private func room(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int) -> Room {
        Room(from: Cell(x: x1, y: y1), to: Cell(x: x2, y: y2))
    }

    @Test func roomSpansItsCornersInEitherOrder() {
        let dragged = room(4, 5, 2, 1)

        #expect(dragged == room(2, 1, 4, 5))
        #expect(dragged.width == 3)
        #expect(dragged.height == 5)
        #expect(dragged.cells.count == 15)
    }

    @Test func addRoomOpensTheInteriorAndWallsThePerimeter() {
        var maze = Maze(width: 6, height: 6)

        let added = maze.addRoom(room(1, 1, 3, 2))
        #expect(added)

        #expect(maze.isOpen(Cell(x: 1, y: 1), Cell(x: 2, y: 1)))
        #expect(maze.isOpen(Cell(x: 2, y: 1), Cell(x: 2, y: 2)))
        #expect(maze.isOpen(Cell(x: 3, y: 1), Cell(x: 3, y: 2)))
        #expect(!maze.isOpen(Cell(x: 3, y: 1), Cell(x: 4, y: 1)))
        #expect(!maze.isCarved(Cell(x: 4, y: 1)))
        #expect(maze.room(at: Cell(x: 3, y: 2)) != nil)
        #expect(maze.room(at: Cell(x: 4, y: 2)) == nil)
    }

    @Test func roomsThatOverlapOrLeaveTheGridAreRejected() {
        var maze = Maze(width: 6, height: 6)
        maze.addRoom(room(1, 1, 3, 3))

        let addedOverlapping = maze.addRoom(room(3, 3, 4, 4))
        #expect(!addedOverlapping)
        let addedOutsideGrid = maze.addRoom(room(4, 4, 6, 5))
        #expect(!addedOutsideGrid)
        let addedAlongside = maze.addRoom(room(4, 1, 5, 3))
        #expect(addedAlongside)
        #expect(maze.rooms.count == 2)
    }

    @Test func pathIntoARoomOpensADoorwayThatRemovingTheRoomCloses() {
        var maze = Maze(width: 6, height: 6)
        maze.addRoom(room(2, 2, 3, 3))
        maze.carvePath(from: Cell(x: 0, y: 2), to: Cell(x: 2, y: 2))
        #expect(maze.isOpen(Cell(x: 1, y: 2), Cell(x: 2, y: 2)))

        let removed = maze.removeRoom(at: Cell(x: 3, y: 3))
        #expect(removed)

        #expect(maze.rooms.isEmpty)
        #expect(!maze.isCarved(Cell(x: 2, y: 2)))
        #expect(!maze.isOpen(Cell(x: 1, y: 2), Cell(x: 2, y: 2)))
        #expect(maze.isOpen(Cell(x: 0, y: 2), Cell(x: 1, y: 2)))
    }

    @Test func roomAbsorbsPathsAndKeepsTheirOutsideConnections() {
        var maze = Maze(width: 6, height: 6)
        maze.carvePath(from: Cell(x: 0, y: 2), to: Cell(x: 5, y: 2))

        maze.addRoom(room(2, 1, 3, 3))

        #expect(maze.isOpen(Cell(x: 1, y: 2), Cell(x: 2, y: 2)))
        #expect(maze.isOpen(Cell(x: 3, y: 2), Cell(x: 4, y: 2)))
        #expect(maze.isOpen(Cell(x: 2, y: 1), Cell(x: 2, y: 2)))
    }

    @Test func eraseLeavesRoomCellsAlone() {
        var maze = Maze(width: 6, height: 6)
        maze.addRoom(room(1, 1, 2, 2))
        let before = maze

        maze.erase(Cell(x: 1, y: 1))

        #expect(maze == before)
    }

    @Test func markerCyclesThroughEveryStateAndBackToNone() {
        var maze = Maze(width: 6, height: 6)
        maze.addRoom(room(1, 1, 2, 2))
        var seen: [Room.Marker?] = []

        for _ in 0..<4 {
            let cycled = maze.cycleMarker(at: Cell(x: 2, y: 2))
            #expect(cycled)
            seen.append(maze.rooms[0].marker)
        }

        #expect(seen == [.blueStart, .redStart, .end, nil])
        let cycledOutsideRoom = maze.cycleMarker(at: Cell(x: 4, y: 4))
        #expect(!cycledOutsideRoom)
    }

    @Test func codingRoundTripsRoomsAndMarkers() throws {
        var maze = Maze(width: 6, height: 6)
        maze.addRoom(room(1, 1, 2, 2))
        maze.addRoom(room(4, 4, 5, 5))
        maze.cycleMarker(at: Cell(x: 1, y: 1))

        let decoded = try JSONDecoder().decode(Maze.self, from: JSONEncoder().encode(maze))

        #expect(decoded == maze)
    }

    @Test func filesSavedBeforeRoomsStillLoad() throws {
        let json = ###"{"width":2,"height":1,"cells":["##"],"right":["#."],"down":[".."]}"###

        let maze = try JSONDecoder().decode(Maze.self, from: Data(json.utf8))

        #expect(maze.rooms.isEmpty)
        #expect(maze.isOpen(Cell(x: 0, y: 0), Cell(x: 1, y: 0)))
    }
}

@MainActor
struct RoomEditingTests {
    private let directory = URL.temporaryDirectory.appending(path: "MazeToolTests-\(UUID().uuidString)")

    private func makeModel() throws -> EditorModel {
        let store = DocumentStore(directory: directory)
        return EditorModel(document: try store.create(name: "Test", width: 8, height: 8), store: store)
    }

    private func stroke(_ model: EditorModel, _ tool: EditorModel.Tool, _ cells: Cell...) {
        model.tool = tool
        cells.forEach { model.drag(to: $0) }
        model.endStroke()
    }

    @Test func roomIsPreviewedWhileDraggingAndAddedWhenTheStrokeEnds() throws {
        let model = try makeModel()
        model.tool = .room

        model.drag(to: Cell(x: 1, y: 1))
        model.drag(to: Cell(x: 3, y: 4))
        #expect(model.roomPreview == Room(from: Cell(x: 1, y: 1), to: Cell(x: 3, y: 4)))
        #expect(model.canPlaceRoomPreview)
        #expect(model.maze.rooms.isEmpty)

        model.endStroke()
        #expect(model.roomPreview == nil)
        #expect(model.maze.rooms.count == 1)

        model.undo()
        #expect(model.maze.isEmpty)
        #expect(model.maze.rooms.isEmpty)
    }

    @Test func overlappingRoomIsFlaggedAndNotAdded() throws {
        let model = try makeModel()
        stroke(model, .room, Cell(x: 1, y: 1), Cell(x: 3, y: 3))

        model.drag(to: Cell(x: 3, y: 3))
        model.drag(to: Cell(x: 5, y: 5))
        #expect(!model.canPlaceRoomPreview)
        model.endStroke()

        #expect(model.maze.rooms.count == 1)
        #expect(model.undoStack.count == 1)
    }

    @Test func markToolCyclesARoomsMarkerAsOneUndoStep() throws {
        let model = try makeModel()
        stroke(model, .room, Cell(x: 1, y: 1), Cell(x: 2, y: 2))

        stroke(model, .mark, Cell(x: 2, y: 1))
        #expect(model.maze.rooms[0].marker == .blueStart)

        stroke(model, .mark, Cell(x: 6, y: 6))
        #expect(model.undoStack.count == 2)

        model.undo()
        #expect(model.maze.rooms[0].marker == nil)
    }

    @Test func eraseRemovesARoomOnlyWhenTheStrokeStartsOnIt() throws {
        let model = try makeModel()
        stroke(model, .room, Cell(x: 3, y: 3), Cell(x: 4, y: 4))
        stroke(model, .path, Cell(x: 0, y: 3), Cell(x: 3, y: 3))

        stroke(model, .erase, Cell(x: 1, y: 3), Cell(x: 5, y: 3))
        #expect(model.maze.rooms.count == 1)
        #expect(!model.maze.isCarved(Cell(x: 2, y: 3)))
        #expect(!model.maze.isOpen(Cell(x: 2, y: 3), Cell(x: 3, y: 3)))

        stroke(model, .erase, Cell(x: 4, y: 4))
        #expect(model.maze.rooms.isEmpty)
        #expect(!model.maze.isCarved(Cell(x: 3, y: 3)))
    }
}
