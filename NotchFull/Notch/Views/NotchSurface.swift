import SwiftUI

/// The material of the open notch for a style; shared by the notch and the settings previews.
struct NotchSurface<S: Shape>: View {
    let style: NotchStyle
    let glassLevel: Double
    let shape: S

    var body: some View {
        switch style {
        case .classic:
            shape.fill(.black)
        case .smokedGlass:
            // Liquid Glass renders in its own layer above sibling content, so a dark layer placed over it never
            // shows. Instead the glass sits over solid black and its opacity sets how much glass survives:
            // a higher level means less glass and more black.
            ZStack {
                shape.fill(.black)
                Color.clear
                    .glassEffect(.regular.tint(.black.opacity(0.5)), in: shape)
                    .opacity(1 - glassLevel * 0.85)
            }
        case .glass:
            Color.clear.glassEffect(.regular, in: shape)
        case .clearGlass:
            Color.clear.glassEffect(.clear, in: shape)
        }
    }
}
