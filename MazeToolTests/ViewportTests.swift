import CoreGraphics
import Foundation
import Testing
@testable import MazeTool

struct ViewportTests {
    private let size = CGSize(width: 400, height: 600)

    @Test func pinchingKeepsTheContentUnderTheFingers() {
        let anchor = CGPoint(x: 300, y: 150)

        let viewport = Viewport.pinched(from: Viewport(), anchor: anchor, location: anchor, scale: 2, in: size)

        #expect(viewport.zoom == 2)
        // The content point that was under the anchor (300, 150) is now at (600, 300) in the zoomed content.
        #expect(viewport.contentPoint(for: anchor) == CGPoint(x: 600, y: 300))
    }

    @Test func movingTheFingersPansWithoutZooming() {
        let start = Viewport(zoom: 2, offset: CGPoint(x: -200, y: -300))

        let viewport = Viewport.pinched(
            from: start, anchor: CGPoint(x: 200, y: 300), location: CGPoint(x: 150, y: 340), scale: 1, in: size
        )

        #expect(viewport == Viewport(zoom: 2, offset: CGPoint(x: -250, y: -260)))
    }

    @Test func zoomIsLimitedToFitAndTheMaximum() {
        let anchor = CGPoint(x: 200, y: 300)

        let out = Viewport.pinched(from: Viewport(), anchor: anchor, location: anchor, scale: 0.2, in: size)
        let far = Viewport.pinched(from: Viewport(), anchor: anchor, location: anchor, scale: 50, in: size)

        #expect(out == Viewport())
        #expect(far.zoom == Viewport.maxZoom)
    }

    @Test func panningStopsAtTheEdgesOfTheContent() {
        let start = Viewport(zoom: 2, offset: CGPoint(x: -200, y: -300))
        let anchor = CGPoint(x: 200, y: 300)

        let pulledRight = Viewport.pinched(from: start, anchor: anchor, location: CGPoint(x: 2000, y: 2000), scale: 1, in: size)
        let pulledLeft = Viewport.pinched(from: start, anchor: anchor, location: CGPoint(x: -2000, y: -2000), scale: 1, in: size)

        #expect(pulledRight.offset == .zero)
        #expect(pulledLeft.offset == CGPoint(x: -400, y: -600))
    }

    @Test func zoomingBackOutReturnsToFit() {
        let zoomed = Viewport(zoom: 3, offset: CGPoint(x: -700, y: -900))

        let viewport = Viewport.pinched(
            from: zoomed, anchor: CGPoint(x: 10, y: 10), location: CGPoint(x: 10, y: 10), scale: 0.1, in: size
        )

        #expect(viewport == Viewport())
        #expect(!viewport.isZoomed)
    }
}
