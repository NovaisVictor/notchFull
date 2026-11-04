import Observation
import CoreGraphics

@MainActor
@Observable
final class NotchViewModel {
    /// Physical notch size.
    let closedSize: CGSize
    private let layout: WidgetLayoutStore
    private let liveActivities: LiveActivityCenter
    private let interaction: NotchInteraction
    private(set) var isOpen = false
    /// Pointer is over the trailing live activity slot, which acts as a button instead of opening the notch.
    private(set) var isTrailingSlotHovered = false

    init(closedSize: CGSize, layout: WidgetLayoutStore, liveActivities: LiveActivityCenter, interaction: NotchInteraction) {
        self.closedSize = closedSize
        self.layout = layout
        self.liveActivities = liveActivities
        self.interaction = interaction
    }

    /// Typing in the notch keeps it open even if the pointer drifts away.
    var isPinnedOpen: Bool {
        interaction.isEditingText
    }

    func endTextEditing() {
        interaction.isEditingText = false
    }

    var activity: LiveActivityCenter.Activity? {
        liveActivities.current
    }

    /// Closed size including the live activity slots on each side, when one is running.
    var closedDisplaySize: CGSize {
        guard activity != nil else { return closedSize }
        let side = LiveActivityCenter.sideWidth(closedHeight: closedSize.height)
        return CGSize(width: closedSize.width + side * 2, height: closedSize.height)
    }

    var openSize: CGSize {
        WidgetGridMetrics.openSize(for: layout.enabled, closedHeight: closedSize.height)
    }

    var currentSize: CGSize {
        isOpen ? openSize : closedDisplaySize
    }

    /// Whether the trailing slot is interactive for the current activity.
    var hasInteractiveTrailingSlot: Bool {
        activity == .media
    }

    func open() {
        isTrailingSlotHovered = false
        isOpen = true
    }

    func setTrailingSlotHovered(_ isHovered: Bool) {
        guard isTrailingSlotHovered != isHovered else { return }
        isTrailingSlotHovered = isHovered
    }

    func close() {
        isOpen = false
    }
}
