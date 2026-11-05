import AppKit

/// Notch measurements for one screen, in global screen coordinates (bottom-left origin).
struct NotchGeometry {
    let screenFrame: CGRect
    /// The band the notch occupies when closed: the physical notch, or on screens without one a menu-bar-high
    /// area the size of the handle's width. Live activities and hover use this band.
    let closedSize: CGSize
    let hasPhysicalNotch: Bool
    /// The small bar drawn at rest on screens without a notch; `nil` on notched screens.
    let handleSize: CGSize?

    @MainActor
    init(screen: NSScreen, settings: ScreenSettings) {
        screenFrame = screen.frame

        // The menu bar areas on each side of the housing are exact; the gap between them is the notch.
        if screen.hasPhysicalNotch,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            closedSize = CGSize(
                width: screen.frame.width - left.width - right.width,
                height: screen.safeAreaInsets.top
            )
            hasPhysicalNotch = true
            handleSize = nil
        } else {
            closedSize = CGSize(width: settings.handleWidth, height: screen.menuBarHeight)
            hasPhysicalNotch = false
            handleSize = CGSize(width: settings.handleWidth, height: settings.handleHeight)
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
