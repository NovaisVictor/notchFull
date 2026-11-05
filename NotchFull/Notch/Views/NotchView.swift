import SwiftUI

struct NotchView: View {
    let model: NotchViewModel
    let services: AppServices
    let openSettings: () -> Void

    private var topRadius: CGFloat { model.isRestingOnHandle ? 0 : model.isOpen ? 14 : 6 }
    private var bottomRadius: CGFloat { model.isOpen ? 28 : model.isPeeking ? 16 : 10 }

    var body: some View {
        // The shape is widened by the ears so the body under the menu bar matches the physical notch.
        let size = model.currentSize

        background
            .frame(width: size.width + topRadius * 2, height: size.height)
            .overlay {
                if model.isOpen {
                    WidgetGrid(services: services)
                        .padding(.horizontal, topRadius + WidgetGridMetrics.horizontalPadding)
                        .padding(.top, model.closedSize.height + WidgetGridMetrics.topGap)
                        .padding(.bottom, WidgetGridMetrics.bottomPadding)
                        .transition(.opacity)
                } else if let activity = model.activity {
                    LiveActivityView(
                        activity: activity,
                        services: services,
                        closedSize: model.closedSize,
                        hoveredSlot: model.hasInteractiveSlots ? model.hoveredSlot : .none
                    )
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .topTrailing) {
                if model.isOpen {
                    settingsButton
                        .padding(.trailing, topRadius + WidgetGridMetrics.horizontalPadding)
                        .frame(height: model.closedSize.height)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.38, dampingFraction: 0.8), value: model.isOpen)
            .animation(.spring(response: 0.38, dampingFraction: 0.8), value: size)
            .animation(.spring(response: 0.38, dampingFraction: 0.8), value: model.activity)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: model.isPeeking)
            .environment(\.notchStyle, style)
    }

    private var style: NotchStyle {
        services.appearance.notchStyle
    }

    // Closed, the notch stays black to blend with the camera housing; glass applies only when open.
    @ViewBuilder
    private var background: some View {
        if model.isRestingOnHandle {
            handle
        } else {
            notchBackground
        }
    }

    @ViewBuilder
    private var notchBackground: some View {
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
        let usesGlass = model.isOpen && style.usesGlass

        ZStack {
            shape.fill(.black)
                .opacity(usesGlass ? 0 : 1)
            if usesGlass {
                NotchSurface(style: style, glassLevel: services.appearance.glassLevel, shape: shape)
                    .transition(.opacity)
            }
        }
    }

    /// The bar that marks the notch on screens without one.
    private var handle: some View {
        let screens = services.screens
        let height = model.handleSize?.height ?? 0
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: height / 2, bottomTrailingRadius: height / 2, style: .continuous)
        let fill: Color = !screens.showsHandle ? .clear : screens.handleIsTransparent ? .white.opacity(0.28) : .black

        return shape.fill(fill)
    }

    // Sits in the top band beside the camera housing, which widgets never use.
    private var settingsButton: some View {
        Button(action: openSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Settings")
    }
}
