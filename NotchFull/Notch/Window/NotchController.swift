import AppKit

/// Owns the notch window and state for one screen.
@MainActor
final class NotchController {
    /// Extra margin around the closed notch so the hover target is easy to hit.
    private static let closedHoverInset = CGSize(width: 12, height: 6)
    /// Margin around the open notch before the pointer counts as leaving it.
    private static let openHoverInset = CGSize(width: 24, height: 24)

    let geometry: NotchGeometry
    private let model: NotchViewModel
    private let window: NotchWindow

    /// Stable identity of the screen this controller serves.
    let displayUUID: String?
    private var isHiddenForFullscreen = false

    init(screen: NSScreen, services: AppServices, openSettings: @escaping () -> Void) {
        geometry = NotchGeometry(screen: screen, settings: services.screens)
        displayUUID = screen.displayUUID
        model = NotchViewModel(
            geometry: geometry,
            layout: services.layout,
            liveActivities: services.liveActivities,
            interaction: services.interaction
        )

        // Sized for the widest open state so opening never resizes the window; the shape animates inside it.
        let maxOpenSize = WidgetGridMetrics.maxOpenSize(closedHeight: geometry.closedSize.height)
        let frame = geometry.topCenteredRect(size: CGSize(width: maxOpenSize.width + 64, height: maxOpenSize.height + 16))
        window = NotchWindow(contentRect: frame)

        let hostingView = FirstMouseHostingView(rootView: NotchView(model: model, services: services, openSettings: openSettings))
        hostingView.sizingOptions = []
        window.contentView = hostingView

        // Transparent window areas would otherwise swallow clicks meant for the menu bar and apps below.
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()

        // Clicking another app ends typing in the notch, so it may close again. Lives as long as the window.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak model] _ in
            MainActor.assumeIsolated { model?.endTextEditing() }
        }
    }

    /// Hides the notch while a full-screen app covers this screen, without recreating the window.
    func setHiddenForFullscreen(_ hidden: Bool) {
        guard hidden != isHiddenForFullscreen else { return }
        isHiddenForFullscreen = hidden
        if hidden {
            model.close()
            window.ignoresMouseEvents = true
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    func handleMouseMoved(to location: CGPoint) {
        guard !isHiddenForFullscreen else { return }
        if model.isOpen {
            let openRect = geometry.topCenteredRect(size: model.openSize)
                .insetBy(dx: -Self.openHoverInset.width, dy: -Self.openHoverInset.height)
            if !openRect.contains(location), !model.isPinnedOpen {
                model.close()
                window.ignoresMouseEvents = true
            }
        } else {
            handleClosedMouseMoved(to: location)
        }
    }

    private func handleClosedMouseMoved(to location: CGPoint) {
        // The display rect includes the peek strip while peeking; the top band is the menu-bar-high row.
        let displayRect = geometry.topCenteredRect(size: model.closedInteractionSize)
        let bandHeight = geometry.closedSize.height
        let side = LiveActivityCenter.sideWidth(closedHeight: bandHeight)
        let topBand = CGRect(x: displayRect.minX, y: displayRect.maxY - bandHeight, width: displayRect.width, height: bandHeight)
        let leadingSlot = CGRect(x: topBand.minX, y: topBand.minY, width: side, height: bandHeight)
        let trailingSlot = CGRect(x: topBand.maxX - side, y: topBand.minY, width: side, height: bandHeight)
        let peekStrip = CGRect(x: displayRect.minX, y: displayRect.minY, width: displayRect.width, height: displayRect.height - bandHeight)

        if model.hasInteractiveSlots {
            if trailingSlot.contains(location) {
                // The slot is a button: accept clicks without opening the notch.
                model.setHoveredSlot(.trailing)
                window.ignoresMouseEvents = false
                return
            }
            // While peeking, the strip below belongs to the peek so the pointer can rest on it to read.
            if leadingSlot.contains(location) || (model.isPeeking && peekStrip.contains(location)) {
                model.setHoveredSlot(.leading)
                window.ignoresMouseEvents = false
                return
            }
        }
        model.setHoveredSlot(.none)

        // The rest of the closed notch opens it: the center between interactive slots, or all of it otherwise.
        let openTarget: CGRect
        if model.hasInteractiveSlots {
            openTarget = CGRect(x: leadingSlot.maxX, y: topBand.minY, width: trailingSlot.minX - leadingSlot.maxX, height: bandHeight)
                .insetBy(dx: 0, dy: -Self.closedHoverInset.height)
        } else {
            openTarget = topBand.insetBy(dx: -Self.closedHoverInset.width, dy: -Self.closedHoverInset.height)
        }
        if openTarget.contains(location) {
            model.open()
            window.ignoresMouseEvents = false
        } else {
            window.ignoresMouseEvents = true
        }
    }

    func tearDown() {
        window.close()
    }
}
