import SwiftUI

/// Content of the closed notch while an activity runs: one slot on each side of the camera housing.
struct LiveActivityView: View {
    let activity: LiveActivityCenter.Activity
    let services: AppServices
    let closedSize: CGSize
    let hoveredSlot: NotchViewModel.HoveredSlot

    var body: some View {
        VStack(spacing: 0) {
            ClosedNotchSlots(closedSize: closedSize, sideWidth: activity.sideWidth(closedHeight: closedSize.height)) {
                leading
            } trailing: {
                trailing
            }
            if hoveredSlot == .leading {
                peek
                    .frame(height: NotchViewModel.peekHeight, alignment: .top)
                    .padding(.horizontal, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if activity.heightBelowNotch > 0 {
                below
                    .frame(height: activity.heightBelowNotch, alignment: .top)
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Content an activity draws below the notch without hovering, like the classic HUD.
    @ViewBuilder
    private var below: some View {
        switch activity {
        case let .hud(state, .classic):
            HUDClassicView(state: state)
        default:
            EmptyView()
        }
    }

    /// Details shown below the notch while the pointer rests on the leading slot.
    @ViewBuilder
    private var peek: some View {
        switch activity {
        case .media:
            if let track = services.nowPlaying.nowPlaying {
                MarqueeText(spacing: 40) {
                    let title = Text(track.title).fontWeight(.semibold)
                    let separator = Text(track.artist.isEmpty ? "" : "  ·  ").foregroundStyle(.white.opacity(0.4))
                    let artist = Text(track.artist).foregroundStyle(.white.opacity(0.65))
                    return Text("\(title)\(separator)\(artist)")
                }
                .font(.system(size: 12))
                .foregroundStyle(.white)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .media:
            MediaArtworkView(artwork: services.nowPlaying.nowPlaying?.artwork, cornerRadius: services.mediaSettings.artworkCornerRadius)
                .scaleEffect(hoveredSlot == .leading ? 1.12 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hoveredSlot == .leading)
        case let .power(event, reading):
            PowerActivityLeadingView(event: event, reading: reading)
        case let .bluetooth(device):
            BluetoothActivityLeadingView(device: device)
        case let .download(download):
            DownloadActivityLeadingView(fraction: download.fraction)
        case .downloadFinished:
            DownloadFinishedLeadingView()
        case .upcomingEvent:
            UpcomingEventLeadingView()
        case .pomodoro:
            PomodoroActivityLeadingView(timer: services.pomodoro)
        case let .hud(state, style):
            if style == .embedded {
                HUDEmbeddedLeadingView(state: state)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity {
        case .media:
            MediaTrailingView(
                nowPlaying: services.nowPlaying,
                settings: services.mediaSettings,
                spectrum: services.spectrum,
                isHovered: hoveredSlot == .trailing,
                closedHeight: closedSize.height
            )
        case let .power(event, reading):
            PowerActivityTrailingView(event: event, reading: reading)
        case let .bluetooth(device):
            BluetoothActivityTrailingView(device: device)
        case let .download(download):
            DownloadActivityTrailingView(fraction: download.fraction)
        case .downloadFinished:
            DownloadFinishedTrailingView()
        case let .upcomingEvent(event):
            UpcomingEventTrailingView(event: event)
        case .pomodoro:
            PomodoroActivityTrailingView(timer: services.pomodoro)
        case let .hud(state, style):
            if style == .embedded {
                HUDEmbeddedTrailingView(state: state)
            }
        }
    }
}

/// Lays out a leading and trailing slot around the camera housing; shared by the notch and settings previews.
struct ClosedNotchSlots<Leading: View, Trailing: View>: View {
    let closedSize: CGSize
    /// Width of each slot; `nil` uses the standard square slot.
    var sideWidth: CGFloat?
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let side = sideWidth ?? LiveActivityCenter.sideWidth(closedHeight: closedSize.height)

        HStack(spacing: 0) {
            leading
                .frame(width: side, height: closedSize.height)
            Color.clear
                .frame(width: closedSize.width)
            trailing
                .frame(width: side, height: closedSize.height)
        }
    }
}
