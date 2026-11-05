import AppKit

/// Turns one two-finger trackpad swipe into at most one discrete gesture.
struct NotchGestureRecognizer {
    enum Gesture: Equatable {
        /// Fingers moved down / up / left / right, regardless of the natural scrolling setting.
        case down
        case up
        case left
        case right
    }

    /// Distance the fingers travel along one axis before the swipe counts.
    private static let threshold: CGFloat = 40

    private var travel = CGVector.zero
    private var hasFired = false

    /// Feeds a scroll event; returns the gesture the first time the swipe crosses the threshold.
    /// Mouse wheels and momentum scrolling are ignored so a flick does not fire twice.
    mutating func handle(_ event: NSEvent) -> Gesture? {
        guard event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty else { return nil }

        if event.phase.contains(.began) {
            travel = .zero
            hasFired = false
        }
        guard event.phase.contains(.began) || event.phase.contains(.changed) else {
            return nil
        }

        // With natural scrolling the deltas already follow the fingers; otherwise they are inverted.
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        travel.dx += event.scrollingDeltaX * sign
        travel.dy += event.scrollingDeltaY * sign

        guard !hasFired else { return nil }
        let horizontal = abs(travel.dx)
        let vertical = abs(travel.dy)
        guard max(horizontal, vertical) >= Self.threshold else { return nil }

        hasFired = true
        if vertical >= horizontal {
            return travel.dy > 0 ? .down : .up
        }
        return travel.dx > 0 ? .right : .left
    }
}
