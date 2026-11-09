import CoreGraphics

/// How the editor's canvas is zoomed and panned. Editor state, not saved with the maze.
struct Viewport: Equatable {
    static let maxZoom: CGFloat = 5

    /// 1 fits the whole grid in the view.
    var zoom: CGFloat = 1
    /// Where the zoomed content's top-left corner sits relative to the view's. Never positive.
    var offset = CGPoint.zero

    var isZoomed: Bool { zoom > 1 }

    /// The size of the zoomed content for a view of the given size.
    func contentSize(in size: CGSize) -> CGSize {
        CGSize(width: size.width * zoom, height: size.height * zoom)
    }

    /// Converts a point in the view to the matching point in the zoomed content.
    func contentPoint(for point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - offset.x, y: point.y - offset.y)
    }

    /// The viewport a two-finger gesture leads to. `start` is the viewport when the gesture
    /// began with its centre at `anchor`; the centre is now at `location` and the fingers have
    /// spread by `scale`. The content under the fingers stays under them, so one gesture both
    /// zooms and pans.
    static func pinched(
        from start: Viewport, anchor: CGPoint, location: CGPoint, scale: CGFloat, in size: CGSize
    ) -> Viewport {
        let zoom = min(max(start.zoom * scale, 1), maxZoom)
        let applied = zoom / start.zoom
        var viewport = Viewport(
            zoom: zoom,
            offset: CGPoint(
                x: location.x - (anchor.x - start.offset.x) * applied,
                y: location.y - (anchor.y - start.offset.y) * applied
            )
        )
        viewport.clamp(in: size)
        return viewport
    }

    /// Keeps the content covering the view, so panning can't drag it off screen.
    mutating func clamp(in size: CGSize) {
        offset.x = min(max(offset.x, size.width * (1 - zoom)), 0)
        offset.y = min(max(offset.y, size.height * (1 - zoom)), 0)
    }
}
