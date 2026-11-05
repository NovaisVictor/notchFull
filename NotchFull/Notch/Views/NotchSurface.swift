import AppKit
import SwiftUI

/// Where a glass surface gets the image it blurs.
enum GlassSource {
    /// What is behind the window: the wallpaper and other apps. Used by the real notch.
    case behindWindow
    /// What is behind the view inside the same window. Used by settings previews, which draw their own wallpaper.
    case withinWindow
}

/// The material of the open notch for a style; shared by the notch and the settings previews.
///
/// SwiftUI's `glassEffect` only refracts content inside its own view, so in a transparent window it renders as
/// flat gray. Glass styles instead use `NSVisualEffectView`, which asks the window server for the pixels behind
/// the window, masked to the notch outline; tint and a rim highlight on top give the Liquid Glass look.
struct NotchSurface: View {
    let style: NotchStyle
    let glassLevel: Double
    let topRadius: CGFloat
    let bottomRadius: CGFloat
    var source: GlassSource = .behindWindow

    var body: some View {
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)

        switch style {
        case .classic:
            shape.fill(.black)
        case .smokedGlass:
            glass(shape: shape, tint: .black.opacity(0.2 + glassLevel * 0.6))
        case .glass:
            glass(shape: shape, tint: .black.opacity(0.1))
        case .clearGlass:
            // Apple's guidance for clear glass: a 35% dark dimming layer keeps text legible over bright content.
            glass(shape: shape, tint: .black.opacity(0.35))
        }
    }

    private func glass(shape: NotchShape, tint: Color) -> some View {
        ZStack {
            BlurBackdrop(
                material: style == .clearGlass ? .underWindowBackground : .fullScreenUI,
                source: source,
                topRadius: topRadius,
                bottomRadius: bottomRadius
            )
            shape.fill(tint)
            // A faint light falling from the top, as on Apple's glass.
            shape.fill(LinearGradient(colors: [.white.opacity(0.07), .clear], startPoint: .top, endPoint: .center))
            // The rim catches light on the leading side and fades around the outline.
            shape.stroke(
                LinearGradient(
                    colors: [.white.opacity(0.55), .white.opacity(0.12), .white.opacity(0.06), .white.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.2
            )
        }
    }
}

/// `NSVisualEffectView` clipped to the notch outline through its mask image, which the window server honors
/// for behind-window blending (a layer mask would not limit the blurred region).
private struct BlurBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let source: GlassSource
    let topRadius: CGFloat
    let bottomRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        // A fixed dark appearance keeps the glass consistent whatever the system appearance is.
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = source == .behindWindow ? .behindWindow : .withinWindow
        let mask = NotchMaskImage.image(topRadius: topRadius, bottomRadius: bottomRadius)
        if view.maskImage !== mask {
            view.maskImage = mask
        }
    }
}

/// A stretchable image of the notch outline: the ears and the rounded corners sit in the cap insets and the straight
/// middle stretches, so one small image fits every size while the notch animates.
@MainActor
private enum NotchMaskImage {
    private static var cache: [String: NSImage] = [:]

    static func image(topRadius: CGFloat, bottomRadius: CGFloat) -> NSImage {
        let key = "\(topRadius)-\(bottomRadius)"
        if let cached = cache[key] {
            return cached
        }
        let horizontalCap = topRadius + bottomRadius
        let size = CGSize(width: horizontalCap * 2 + 1, height: topRadius + bottomRadius + 1)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(NotchShape(topRadius: topRadius, bottomRadius: bottomRadius).path(in: rect).cgPath)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            return true
        }
        image.capInsets = NSEdgeInsets(top: topRadius, left: horizontalCap, bottom: bottomRadius, right: horizontalCap)
        image.resizingMode = .stretch
        cache[key] = image
        return image
    }
}
