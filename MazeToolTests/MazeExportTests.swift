import Foundation
import Testing
import UIKit
@testable import MazeTool

@MainActor
struct MazeExportTests {
    /// A 4 × 4 maze with a blue Start, a short path and an End, so both styles have content.
    private func makeDocument() -> MazeDocument {
        var document = MazeDocument(name: "Harbor v1", width: 4, height: 4)
        document.maze.addRoom(Room(from: Cell(x: 0, y: 0), to: Cell(x: 0, y: 0)))
        document.maze.cycleMarker(at: Cell(x: 0, y: 0))
        document.maze.addRoom(Room(from: Cell(x: 3, y: 2), to: Cell(x: 3, y: 2)))
        for _ in 0..<3 { document.maze.cycleMarker(at: Cell(x: 3, y: 2)) }
        document.maze.carvePath(from: Cell(x: 0, y: 0), to: Cell(x: 3, y: 0))
        document.maze.carvePath(from: Cell(x: 3, y: 0), to: Cell(x: 3, y: 2))
        return document
    }

    /// RGBA of the pixel at a point given in cell units from the grid's top-left corner.
    private func pixel(of image: UIImage, atCellX x: CGFloat, y: CGFloat, in document: MazeDocument) throws -> [UInt8] {
        let cgImage = try #require(image.cgImage)
        let inset = (document.settings.wallThickness / 2).rounded(.up)
        let px = Int((x * MazeExport.cellPoints + inset) * MazeExport.scale)
        let py = Int((y * MazeExport.cellPoints + inset) * MazeExport.scale)
        var rgba = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: -px, y: py - cgImage.height + 1, width: cgImage.width, height: cgImage.height))
        return rgba
    }

    @Test(arguments: MazeExport.Style.allCases)
    func imageHasTheExpectedPixelSize(style: MazeExport.Style) throws {
        let document = makeDocument()

        let image = try #require(MazeExport.image(of: document, style: style)).cgImage

        let expected = MazeExport.pixelSize(of: document)
        #expect(image?.width == Int(expected.width))
        #expect(image?.height == Int(expected.height))
        #expect(Int(expected.width) == 392)
    }

    @Test func mazeStyleIsBlackWallsOnTransparency() throws {
        let document = makeDocument()
        let image = try #require(MazeExport.image(of: document, style: .maze))

        // The middle of a path cell, the middle of an uncarved cell, and the wall under the path.
        #expect(try pixel(of: image, atCellX: 1.5, y: 0.5, in: document)[3] == 0)
        #expect(try pixel(of: image, atCellX: 1.5, y: 2.5, in: document)[3] == 0)
        #expect(try pixel(of: image, atCellX: 1.5, y: 1.0, in: document) == [0, 0, 0, 255])
    }

    @Test func overlayStyleTintsTheRouteAndLeavesDeadSpaceTransparent() throws {
        let document = makeDocument()
        let image = try #require(MazeExport.image(of: document, style: .overlay))

        let path = try pixel(of: image, atCellX: 1.5, y: 0.5, in: document)
        #expect(path[3] > 0)
        #expect(path[2] > path[0])
        #expect(try pixel(of: image, atCellX: 1.5, y: 2.5, in: document)[3] == 0)
        #expect(try pixel(of: image, atCellX: 1.5, y: 1.0, in: document) == [0, 0, 0, 255])
    }

    @Test func pngFilesAreNamedAfterTheMazeAndStyle() throws {
        let url = try MazeExport.writePNG(of: makeDocument(), style: .overlay)

        #expect(url.lastPathComponent == "Harbor v1-overlay.png")
        #expect(try Data(contentsOf: url).prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
        #expect(MazeExport.fileName(for: "a/b:c") == "a-b-c")
        #expect(MazeExport.fileName(for: "  ") == "maze")
    }
}
