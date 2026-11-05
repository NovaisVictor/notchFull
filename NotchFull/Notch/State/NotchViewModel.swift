import Observation
import CoreGraphics

@MainActor
@Observable
final class NotchViewModel {
    /// The closed band: the physical notch, or a menu-bar-high band on screens without one.
    let closedSize: CGSize
    /// The bar drawn at rest on screens without a notch; `nil` on notched screens.
    let handleSize: CGSize?
    private let layout: WidgetLayoutStore
    private let liveActivities: LiveActivityCenter
    private let interaction: NotchInteraction
    private let behavior: BehaviorSettings
    private(set) var isOpen = false
    /// Click-to-open mode: the pointer rests where a click would open the notch.
    private(set) var isHoveringToOpen = false
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

    init(
        geometry: NotchGeometry,
        layout: WidgetLayoutStore,
        liveActivities: LiveActivityCenter,
        interaction: NotchInteraction,
        behavior: BehaviorSettings
    ) {
        closedSize = geometry.closedSize
        handleSize = geometry.handleSize
        self.layout = layout
        self.liveActivities = liveActivities
        self.interaction = interaction
        self.behavior = behavior
    }

    /// Typing in the notch keeps it open even if the pointer drifts away, unless the user turned that off.
    var isPinnedOpen: Bool {
        interaction.isEditingText && behavior.keepsOpenWhileTyping
    }

    func endTextEditing() {
        interaction.isEditingText = false
    }

    var activity: LiveActivityCenter.Activity? {
        liveActivities.current
    }

    /// Closed and idle on a screen without a notch: only the small handle is drawn.
    var isRestingOnHandle: Bool {
        handleSize != nil && !isOpen && activity == nil
    }

    /// What the closed notch draws: the handle or the notch at rest, plus live activity slots and the peek strip.
    var closedDisplaySize: CGSize {
        guard activity != nil else { return handleSize ?? closedSize }
        let side = LiveActivityCenter.sideWidth(closedHeight: closedSize.height)
        let height = closedSize.height + (isPeeking ? Self.peekHeight : 0)
        return CGSize(width: closedSize.width + side * 2, height: height)
    }

    /// Area of the closed notch that reacts to the pointer; at rest it is the whole band, larger than the handle.
    var closedInteractionSize: CGSize {
        activity == nil ? closedSize : closedDisplaySize
    }

    var isPeeking: Bool {
        hasInteractiveSlots && hoveredSlot == .leading
    }

    var openSize: CGSize {
        WidgetGridMetrics.openSize(for: layout.placements.map(\.span), closedHeight: closedSize.height)
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
        isHoveringToOpen = false
        isOpen = true
    }

    func setHoveringToOpen(_ isHovering: Bool) {
        guard isHoveringToOpen != isHovering else { return }
        isHoveringToOpen = isHovering
    }

    func setHoveredSlot(_ slot: HoveredSlot) {
        guard hoveredSlot != slot else { return }
        hoveredSlot = slot
    }

    func close() {
        isOpen = false
    }
}
