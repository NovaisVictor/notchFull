import SwiftUI

/// Stand-in for a dark desktop wallpaper with neon strokes, so previews show how glass and black read
/// against color without depending on the user's real wallpaper.
struct WallpaperBackdrop: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.03)))

            let strokes: [(color: Color, x: CGFloat, amplitude: CGFloat, phase: CGFloat)] = [
                (.cyan, 0.36, 18, 0),
                (.blue, 0.42, 26, 1.4),
                (.pink, 0.58, 22, 0.6),
                (.purple, 0.66, 30, 2.2),
                (.pink, 0.72, 14, 3.1),
            ]
            for stroke in strokes {
                var path = Path()
                let steps = 40
                for step in 0...steps {
                    let progress = CGFloat(step) / CGFloat(steps)
                    let y = size.height * (0.35 + 0.65 * progress)
                    let x = size.width * stroke.x + sin(progress * 5 + stroke.phase) * stroke.amplitude
                    step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
                var glow = context
                glow.addFilter(.blur(radius: 6))
                glow.stroke(path, with: .color(stroke.color.opacity(0.8)), lineWidth: 5)
                context.stroke(path, with: .color(stroke.color), lineWidth: 1.5)
            }
        }
    }
}

enum PreviewMetrics {
    static let closedSize = CGSize(width: 170, height: 32)
}

/// The closed notch with an activity, on a wallpaper strip.
struct ClosedNotchPreview<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let closedSize = PreviewMetrics.closedSize
        let side = LiveActivityCenter.sideWidth(closedHeight: closedSize.height)

        ZStack(alignment: .top) {
            WallpaperBackdrop()
            ClosedNotchSlots(closedSize: closedSize) {
                leading
            } trailing: {
                trailing
            }
            .foregroundStyle(.white)
            .background {
                NotchShape(topRadius: 6, bottomRadius: 10)
                    .fill(.black)
                    .padding(.horizontal, -6)
            }
            .frame(width: closedSize.width + side * 2)
        }
        .frame(height: 76)
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
    }
}

/// The open notch in a given style, wrapping arbitrary content below the camera band.
struct OpenNotchPreview<Content: View>: View {
    let style: NotchStyle
    var glassLevel: Double = AppearanceSettings.defaultGlassLevel
    let size: CGSize
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            WallpaperBackdrop()
            content
                .padding(.top, PreviewMetrics.closedSize.height + 6)
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
                .frame(width: size.width, height: size.height)
                .background {
                    NotchSurface(style: style, glassLevel: glassLevel, shape: NotchShape(topRadius: 10, bottomRadius: 22))
                }
                .environment(\.notchStyle, style)
        }
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
    }
}

/// Abstract widgets (artwork, text lines, tiles) for previews that show a style, not real data.
struct NookSkeleton: View {
    @Environment(\.notchStyle) private var style

    var body: some View {
        HStack(spacing: 8) {
            tile.aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 5) {
                bar(width: 46, opacity: 0.55)
                bar(width: 30, opacity: 0.3)
                Spacer(minLength: 0)
                bar(width: 70, opacity: 0.25)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 6) {
                tile
                tile
            }
            .frame(width: 36)
        }
    }

    private var tile: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(style == .classic ? Color(white: 0.16) : .white.opacity(0.1))
    }

    private func bar(width: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill(.white.opacity(opacity))
            .frame(width: width, height: 4)
    }
}

/// Sample values for previews, so settings never depend on what is playing right now.
enum PreviewSamples {
    static let track = NowPlaying(
        title: "Midnight Drive",
        artist: "Neon Coast",
        album: "Afterglow",
        isPlaying: true,
        duration: 183,
        position: 73,
        positionDate: .now
    )

    static let battery = BatteryMonitor.Reading(level: 0.78, isCharging: true, isOnACPower: true)

    static let airpods = BluetoothDevice(
        address: "00:00:00:00:00:00",
        name: "AirPods",
        kind: .airpodsPro,
        isConnected: true,
        batteryLevel: 0.78
    )

    static func upcomingEvent(leadMinutes: Int) -> UpcomingEvent {
        UpcomingEvent(title: "Design review", start: .now.addingTimeInterval(TimeInterval(leadMinutes * 60)))
    }

    static let download = DownloadsMonitor.Download(id: UUID(), fileName: "Report.pdf", startedAt: .now, fraction: 0.62)
}
