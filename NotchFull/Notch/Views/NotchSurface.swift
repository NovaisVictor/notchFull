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
            // Black-tinted glass keeps the edge refraction; the extra black layer sets how much wallpaper survives.
            Color.clear
                .glassEffect(.regular.tint(.black.opacity(glassLevel)), in: shape)
                .overlay(shape.fill(.black.opacity(glassLevel * 0.6)))
        case .glass:
            Color.clear.glassEffect(.regular, in: shape)
        case .clearGlass:
            Color.clear.glassEffect(.clear, in: shape)
        }
    }
}
