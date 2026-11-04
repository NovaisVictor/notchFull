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
    /// Slot of the closed notch under the pointer. Interactive slots act on their own instead of opening the notch:
    /// the leading one peeks at details below the notch, the trailing one is a button.
    private(set) var hoveredSlot: HoveredSlot = .none

    enum HoveredSlot {
        case none
        case leading
        case trailing
    }

    /// Height of the strip shown below the closed notch while peeking.
    static let peekHeight: CGFloat = 24

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

    /// Closed size including the live activity slots on each side, and the peek strip while peeking.
    var closedDisplaySize: CGSize {
        guard activity != nil else { return closedSize }
        let side = LiveActivityCenter.sideWidth(closedHeight: closedSize.height)
        let height = closedSize.height + (isPeeking ? Self.peekHeight : 0)
        return CGSize(width: closedSize.width + side * 2, height: height)
    }

    var isPeeking: Bool {
        hasInteractiveSlots && hoveredSlot == .leading
    }

    var openSize: CGSize {
        WidgetGridMetrics.openSize(for: layout.enabled, closedHeight: closedSize.height)
    }

    var currentSize: CGSize {
        isOpen ? openSize : closedDisplaySize
    }

    /// Whether the side slots are interactive for the current activity.
    var hasInteractiveSlots: Bool {
        activity == .media
    }

    func open() {
        hoveredSlot = .none
        isOpen = true
    }

    func setHoveredSlot(_ slot: HoveredSlot) {
        guard hoveredSlot != slot else { return }
        hoveredSlot = slot
    }

    func close() {
        isOpen = false
    }
}
