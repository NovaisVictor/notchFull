import AppKit
import Observation
import SwiftUI

/// Owns the notch window and state for one screen.
@MainActor
final class NotchController {
    /// Extra margin around the closed notch so the hover target is easy to hit.
    private static let closedHoverInset = CGSize(width: 12, height: 6)
    /// Margin around the open notch before the pointer counts as leaving it.
    private static let openHoverInset = CGSize(width: 24, height: 24)

    let geometry: NotchGeometry
    /// Stable identity of the screen this controller serves.
    let displayUUID: String?
    private let model: NotchViewModel
    private let window: NotchWindow
    private let behavior: BehaviorSettings
    private let nowPlaying: NowPlayingStore
    private var isHiddenForFullscreen = false
    private var gestures = NotchGestureRecognizer()
    private let satellites: SatelliteCenter
    private let satelliteWindow: NotchWindow
    private let satelliteHover = SatelliteHoverState()
    private var isSatelliteVisible = false

    init(screen: NSScreen, services: AppServices, openSettings: @escaping () -> Void) {
        geometry = NotchGeometry(screen: screen, settings: services.screens)
        displayUUID = screen.displayUUID
        behavior = services.behavior
        nowPlaying = services.nowPlaying
        satellites = services.satellites
        model = NotchViewModel(
            geometry: geometry,
            layout: services.layout,
            liveActivities: services.liveActivities,
            interaction: services.interaction,
            behavior: services.behavior
        )

        // Sized for the widest open state so opening never resizes the window; the shape animates inside it.
        let maxOpenSize = WidgetGridMetrics.maxOpenSize(closedHeight: geometry.closedSize.height)
        let frame = geometry.topCenteredRect(size: CGSize(width: maxOpenSize.width + 64, height: maxOpenSize.height + 16))
        window = NotchWindow(contentRect: frame)

        // Satellites float just below the menu bar, beside the notch and its activity slot, so they never
        // cover menu bar items or the notch itself.
        let side = LiveActivityCenter.sideWidth(closedHeight: geometry.closedSize.height)
        let satelliteSize = CGSize(width: SatelliteCenter.expandedWidth + 8, height: SatelliteCenter.diameter + 4)
        let satelliteOrigin = CGPoint(
            x: geometry.screenFrame.midX + geometry.closedSize.width / 2 + side + SatelliteCenter.margin,
            y: geometry.screenFrame.maxY - geometry.closedSize.height - SatelliteCenter.margin - satelliteSize.height
        )
        satelliteWindow = NotchWindow(contentRect: CGRect(origin: satelliteOrigin, size: satelliteSize))

        let notchView = NotchView(model: model, services: services, openSettings: openSettings) { [weak self] in
            self?.openNotch()
        }
        let hostingView = FirstMouseHostingView(rootView: notchView)
        hostingView.sizingOptions = []
        window.contentView = hostingView

        // Transparent window areas would otherwise swallow clicks meant for the menu bar and apps below.
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()

        let strip = SatelliteHost(center: services.satellites, timer: services.pomodoro, hover: satelliteHover) { [weak self] _ in
            self?.openNotch()
        }
        let satelliteView = FirstMouseHostingView(rootView: strip)
        satelliteView.sizingOptions = []
        satelliteWindow.contentView = satelliteView
        satelliteWindow.ignoresMouseEvents = true
        observeSatelliteVisibility()

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
        updateSatelliteVisibility()
    }

    func handleMouseMoved(to location: CGPoint) {
        guard !isHiddenForFullscreen else { return }
        updateSatelliteHover(at: location)
        if model.isOpen {
            if !openRect.contains(location), !model.isPinnedOpen {
                closeNotch()
            }
        } else {
            handleClosedMouseMoved(to: location)
        }
    }

    /// Trackpad swipes over the notch: down opens, up (over the top band) closes, sideways changes the track.
    func handleScroll(_ event: NSEvent, at location: CGPoint) {
        guard !isHiddenForFullscreen, behavior.gesturesEnabled, isOverGestureArea(location) else { return }
        guard let gesture = gestures.handle(event) else { return }

        switch gesture {
        case .down where !model.isOpen && behavior.verticalGestures:
            openNotch()
        case .up where model.isOpen && behavior.verticalGestures && !model.isPinnedOpen:
            closeNotch()
        case .left, .right:
            // Sideways swipes only act on the closed notch; open, they would fight the widgets' own scrolling.
            guard !model.isOpen, behavior.horizontalMediaGestures, nowPlaying.activePlayer != nil else { return }
            let forward = (gesture == .left) != behavior.invertsMediaGestures
            nowPlaying.send(forward ? .nextTrack : .previousTrack)
            behavior.playHaptic()
        default:
            break
        }
    }

    func tearDown() {
        window.close()
        satelliteWindow.close()
    }

    private var openRect: CGRect {
        geometry.topCenteredRect(size: model.openSize)
            .insetBy(dx: -Self.openHoverInset.width, dy: -Self.openHoverInset.height)
    }

    /// Closed: the notch and its activity slots. Open: only the top band, so vertical swipes inside widgets scroll them.
    private func isOverGestureArea(_ location: CGPoint) -> Bool {
        if model.isOpen {
            let band = geometry.topCenteredRect(size: CGSize(width: model.openSize.width, height: geometry.closedSize.height))
            return band.insetBy(dx: 0, dy: -Self.closedHoverInset.height).contains(location)
        }
        return geometry.topCenteredRect(size: model.closedInteractionSize)
            .insetBy(dx: -Self.closedHoverInset.width, dy: -Self.closedHoverInset.height)
            .contains(location)
    }

    /// Shown while any satellite is active and the notch is closed; the open notch shows the same information.
    private func observeSatelliteVisibility() {
        withObservationTracking {
            updateSatelliteVisibility()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSatelliteVisibility() }
        }
    }

    private func updateSatelliteVisibility() {
        let shouldShow = !satellites.active.isEmpty && !model.isOpen && !isHiddenForFullscreen
        guard shouldShow != isSatelliteVisible else { return }
        isSatelliteVisible = shouldShow
        if shouldShow {
            satelliteWindow.orderFrontRegardless()
        } else {
            satelliteHover.hovered = nil
            satelliteWindow.ignoresMouseEvents = true
            satelliteWindow.orderOut(nil)
        }
    }

    /// Only the satellite itself takes the pointer; the rest of its window lets clicks through.
    private func updateSatelliteHover(at location: CGPoint) {
        guard isSatelliteVisible, let first = satellites.active.first else { return }
        let frame = satelliteWindow.frame
        let width = satelliteHover.hovered == nil ? SatelliteCenter.diameter : SatelliteCenter.expandedWidth
        let target = CGRect(x: frame.minX, y: frame.maxY - SatelliteCenter.diameter, width: width, height: SatelliteCenter.diameter)
            .insetBy(dx: -4, dy: -4)
        let isOver = target.contains(location)
        satelliteHover.hovered = isOver ? first : nil
        satelliteWindow.ignoresMouseEvents = !isOver
    }

    private func openNotch() {
        guard !model.isOpen else { return }
        model.open()
        window.ignoresMouseEvents = false
        behavior.playHaptic()
    }

    private func closeNotch() {
        model.close()
        window.ignoresMouseEvents = true
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
                model.setHoveringToOpen(false)
                window.ignoresMouseEvents = false
                return
            }
            // While peeking, the strip below belongs to the peek so the pointer can rest on it to read.
            if leadingSlot.contains(location) || (model.isPeeking && peekStrip.contains(location)) {
                model.setHoveredSlot(.leading)
                model.setHoveringToOpen(false)
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

        guard openTarget.contains(location) else {
            model.setHoveringToOpen(false)
            window.ignoresMouseEvents = true
            return
        }
        if behavior.opensOnHover {
            openNotch()
        } else {
            // Click-to-open: highlight and accept the click that `NotchView` turns into `openNotch()`.
            model.setHoveringToOpen(true)
            window.ignoresMouseEvents = false
        }
    }
}
