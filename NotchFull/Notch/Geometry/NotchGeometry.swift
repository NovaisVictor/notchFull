import AppKit

/// Physical notch measurements for one screen, in global screen coordinates (bottom-left origin).
struct NotchGeometry {
    /// Used on screens without a camera housing so the notch can still be shown and tested.
    static let simulatedClosedSize = CGSize(width: 200, height: 32)

    let screenFrame: CGRect
    let closedSize: CGSize
    let hasPhysicalNotch: Bool

    init(screen: NSScreen) {
        screenFrame = screen.frame

        // The menu bar areas on each side of the housing are exact; the gap between them is the notch.
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            closedSize = CGSize(
                width: screen.frame.width - left.width - right.width,
                height: screen.safeAreaInsets.top
            )
            hasPhysicalNotch = true
        } else {
            closedSize = Self.simulatedClosedSize
            hasPhysicalNotch = false
        }
    }

    /// Rect of a notch-anchored element of `size`, centered and attached to the top edge.
    func topCenteredRect(size: CGSize) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
