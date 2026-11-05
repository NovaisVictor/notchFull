import SwiftUI

struct NotchView: View {
    let model: NotchViewModel
    let services: AppServices
    let openSettings: () -> Void
    /// Opens the notch from a click, used when hovering alone does not open it.
    let onClickToOpen: () -> Void

    private var topRadius: CGFloat { model.isRestingOnHandle ? 0 : model.isOpen ? Self.openTopRadius : 6 }
    private var bottomRadius: CGFloat { model.isOpen ? 28 : model.isExtendedBelow ? 16 : 10 }

    /// Corner radius of the "ears" when open; the open content is laid out for it.
    private static let openTopRadius: CGFloat = 14

    var body: some View {
        // The shape is widened by the ears so the body under the menu bar matches the physical notch.
        let size = model.currentSize
        let frameWidth = size.width + topRadius * 2
        let appearance = services.appearance

        ZStack(alignment: .top) {
            background
                .frame(width: frameWidth, height: size.height)
                .scaleEffect(model.isHoveringToOpen ? 1.06 : 1, anchor: .top)
                .contentShape(.rect)
                .onTapGesture {
                    if !model.isOpen { onClickToOpen() }
                }

            if model.isOpen {
                openContent
                    .transition(.opacity)
            } else if let activity = model.activity {
                LiveActivityView(
                    activity: activity,
                    services: services,
                    closedSize: model.closedSize,
                    hoveredSlot: model.hasInteractiveSlots ? model.hoveredSlot : .none
                )
                .frame(width: frameWidth, height: size.height)
                .transition(.opacity)
            }
        }
        .frame(width: frameWidth, height: size.height, alignment: .top)
        // The open content keeps its final size from the first frame and the growing shape reveals it,
        // so widgets never re-lay out (and slide sideways) while the notch animates.
        .mask(alignment: .top) {
            NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                .frame(width: frameWidth, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(appearance.notchAnimation, value: model.isOpen)
        .animation(appearance.notchAnimation, value: size)
        .animation(appearance.notchAnimation, value: model.activity)
        .animation(appearance.detailAnimation, value: model.isPeeking)
        .animation(appearance.detailAnimation, value: model.isHoveringToOpen)
        .environment(\.notchStyle, style)
    }

    private var openContent: some View {
        let openSize = model.openSize

        return WidgetGrid(services: services)
            .padding(.horizontal, Self.openTopRadius + WidgetGridMetrics.horizontalPadding)
            .padding(.top, model.closedSize.height + WidgetGridMetrics.topGap)
            .padding(.bottom, WidgetGridMetrics.bottomPadding)
            .frame(width: openSize.width + Self.openTopRadius * 2, height: openSize.height)
            .overlay(alignment: .topTrailing) {
                settingsButton
                    .padding(.trailing, Self.openTopRadius + WidgetGridMetrics.horizontalPadding)
                    .frame(height: model.closedSize.height)
            }
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
                NotchSurface(style: style, glassLevel: services.appearance.glassLevel, topRadius: topRadius, bottomRadius: bottomRadius)
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
