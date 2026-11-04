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

    init(screen: NSScreen) {
        geometry = NotchGeometry(screen: screen)
        model = NotchViewModel(closedSize: geometry.closedSize)

        // Sized for the open state so opening never resizes the window; the shape animates inside it.
        let frame = geometry.topCenteredRect(size: Self.windowSize)
        window = NotchWindow(contentRect: frame)

        let hostingView = FirstMouseHostingView(rootView: NotchView(model: model))
        hostingView.sizingOptions = []
        window.contentView = hostingView

        // Transparent window areas would otherwise swallow clicks meant for the menu bar and apps below.
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
    }

    private static var windowSize: CGSize {
        CGSize(width: NotchViewModel.openSize.width + 64, height: NotchViewModel.openSize.height + 16)
    }

    func handleMouseMoved(to location: CGPoint) {
        if model.isOpen {
            let openRect = geometry.topCenteredRect(size: NotchViewModel.openSize)
                .insetBy(dx: -Self.openHoverInset.width, dy: -Self.openHoverInset.height)
            if !openRect.contains(location) {
                model.close()
                window.ignoresMouseEvents = true
            }
        } else {
            let closedRect = geometry.topCenteredRect(size: geometry.closedSize)
                .insetBy(dx: -Self.closedHoverInset.width, dy: -Self.closedHoverInset.height)
            if closedRect.contains(location) {
                model.open()
                window.ignoresMouseEvents = false
            }
        }
    }

    func tearDown() {
        window.close()
    }
}
