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

    init(screen: NSScreen, services: AppServices, openSettings: @escaping () -> Void) {
        geometry = NotchGeometry(screen: screen)
        model = NotchViewModel(
            closedSize: geometry.closedSize,
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

    func handleMouseMoved(to location: CGPoint) {
        if model.isOpen {
            let openRect = geometry.topCenteredRect(size: model.openSize)
                .insetBy(dx: -Self.openHoverInset.width, dy: -Self.openHoverInset.height)
            if !openRect.contains(location), !model.isPinnedOpen {
                model.close()
                window.ignoresMouseEvents = true
            }
        } else {
            let displayRect = geometry.topCenteredRect(size: model.closedDisplaySize)
            let side = LiveActivityCenter.sideWidth(closedHeight: geometry.closedSize.height)
            let trailingSlot = CGRect(x: displayRect.maxX - side, y: displayRect.minY, width: side, height: displayRect.height)

            if model.hasInteractiveTrailingSlot, trailingSlot.contains(location) {
                // The slot is a button: accept clicks without opening the notch.
                model.setTrailingSlotHovered(true)
                window.ignoresMouseEvents = false
                return
            }
            model.setTrailingSlotHovered(false)

            // Everything else in the closed notch opens it, including the leading slot.
            var openTarget = displayRect.insetBy(dx: -Self.closedHoverInset.width, dy: -Self.closedHoverInset.height)
            if model.hasInteractiveTrailingSlot {
                openTarget.size.width = trailingSlot.minX - openTarget.minX
            }
            if openTarget.contains(location) {
                model.open()
                window.ignoresMouseEvents = false
            } else {
                window.ignoresMouseEvents = true
            }
        }
    }

    func tearDown() {
        window.close()
    }
}
