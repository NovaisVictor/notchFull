import SwiftUI

/// Content of the closed notch while an activity runs: one slot on each side of the camera housing.
struct LiveActivityView: View {
    let activity: LiveActivityCenter.Activity
    let services: AppServices
    let closedSize: CGSize
    let isTrailingSlotHovered: Bool

    var body: some View {
        ClosedNotchSlots(closedSize: closedSize) {
            leading
        } trailing: {
            trailing
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .media:
            MediaArtworkView(artwork: services.nowPlaying.nowPlaying?.artwork, cornerRadius: services.mediaSettings.artworkCornerRadius)
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
                isHovered: isTrailingSlotHovered,
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
        }
    }
}

/// Lays out a leading and trailing slot around the camera housing; shared by the notch and settings previews.
struct ClosedNotchSlots<Leading: View, Trailing: View>: View {
    let closedSize: CGSize
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let side = LiveActivityCenter.sideWidth(closedHeight: closedSize.height)

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
