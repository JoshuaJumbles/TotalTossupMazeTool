import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// A two-finger gesture reporting how far the fingers have spread and where their centre is,
/// so one gesture can zoom and pan together.
struct PinchPanGesture: UIGestureRecognizerRepresentable {
    struct Value {
        var scale: CGFloat
        /// The centre of the two fingers, in the view's coordinates.
        var location: CGPoint
    }

    var onBegan: (Value) -> Void
    var onChanged: (Value) -> Void
    var onEnded: () -> Void

    /// Lets the gesture run alongside the one-finger drawing gesture instead of waiting for it to fail.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> TwoFingerRecognizer {
        let recognizer = TwoFingerRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: TwoFingerRecognizer, context: Context) {
        let value = Value(scale: recognizer.scale, location: context.converter.localLocation)
        switch recognizer.state {
        case .began: onBegan(value)
        case .changed: onChanged(value)
        case .ended, .cancelled, .failed: onEnded()
        default: break
        }
    }
}

/// Begins the moment a second finger touches down and ends when either lifts. The system's
/// pinch recognizer waits for the fingers to spread, so it misses a two-finger pan, and its
/// pan recognizer waits for them to travel, so it misses a pinch on the spot.
final class TwoFingerRecognizer: UIGestureRecognizer {
    /// How far apart the fingers are now, relative to when the gesture began.
    private(set) var scale: CGFloat = 1

    private var tracked: [UITouch] = []
    private var startDistance: CGFloat = 1

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches where tracked.count < 2 {
            tracked.append(touch)
        }
        if tracked.count == 2, state == .possible {
            startDistance = max(distance, 1)
            scale = 1
            state = .began
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard tracked.count == 2, state == .began || state == .changed else { return }
        scale = distance / startDistance
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches, as: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches, as: .cancelled)
    }

    override func reset() {
        tracked = []
        scale = 1
    }

    /// The centre of the two tracked fingers.
    override func location(in view: UIView?) -> CGPoint {
        guard tracked.count == 2 else { return super.location(in: view) }
        let a = tracked[0].location(in: view)
        let b = tracked[1].location(in: view)
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private var distance: CGFloat {
        let a = tracked[0].location(in: view)
        let b = tracked[1].location(in: view)
        return hypot(a.x - b.x, a.y - b.y)
    }

    private func finish(_ touches: Set<UITouch>, as endState: UIGestureRecognizer.State) {
        guard tracked.contains(where: touches.contains) else { return }
        // A single finger that lifts without a second ever joining was never this gesture.
        state = (state == .began || state == .changed) ? endState : .failed
    }
}
