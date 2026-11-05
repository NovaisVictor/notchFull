import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// What appears in the closed notch: music and system events, each with a preview and a live test.
struct LiveActivitiesPage: View {
    let services: AppServices

    var body: some View {
        SettingsPage(pane: .liveActivities) {
            MediaActivitySection(settings: services.mediaSettings, spectrum: services.spectrum)
            BatteryActivitySection(settings: services.activitySettings, center: services.liveActivities)
            BluetoothActivitySection(settings: services.activitySettings, monitor: services.bluetooth, center: services.liveActivities)
            DownloadsActivitySection(settings: services.activitySettings, monitor: services.downloads, center: services.liveActivities)
            CalendarActivitySection(settings: services.activitySettings, calendar: services.calendar, center: services.liveActivities)
        }
    }
}

/// Button that plays an activity in the real notch, so the user can see it in place.
private struct ShowInNotchButton: View {
    let action: () -> Void

    var body: some View {
        Button("Show in notch", systemImage: "play.circle", action: action)
            .controlSize(.small)
    }
}

// MARK: - Media

private struct MediaActivitySection: View {
    @Bindable var settings: MediaActivitySettings
    let spectrum: AudioSpectrumSource

    var body: some View {
        SettingsSection(title: "Media", systemImage: "music.note", info: "Shown while music plays in Spotify or Music.") {
            ClosedNotchPreview {
                MediaArtworkView(artwork: nil, cornerRadius: settings.artworkCornerRadius)
            } trailing: {
                effectPreview(settings.effect)
                    .frame(
                        width: MediaVisualizerMetrics.size(for: settings.effect, closedHeight: PreviewMetrics.closedSize.height).width,
                        height: MediaVisualizerMetrics.size(for: settings.effect, closedHeight: PreviewMetrics.closedSize.height).height
                    )
            }
            .padding(.bottom, 12)

            SettingsRow(title: "Show what's playing") {
                Toggle("", isOn: $settings.isEnabled).labelsHidden().toggleStyle(.switch)
            }

            SettingsRow(title: "Album corner radius") {
                HStack {
                    Slider(value: $settings.artworkCornerRadius, in: MediaActivitySettings.artworkCornerRadiusRange, step: 1)
                        .frame(width: 180)
                    Text("\(Int(settings.artworkCornerRadius))")
                        .monospacedDigit()
                        .frame(width: 28)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: .rect(cornerRadius: 6))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                InfoLabel(title: "Effect type", info: "The visualization shown while music plays.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                    ForEach(MediaEffect.allCases) { effect in
                        OptionCard(title: effect.displayName, isSelected: settings.effect == effect) {
                            settings.effect = effect
                        } preview: {
                            effectPreview(effect)
                                .frame(width: 70, height: effect == .spectrograph ? 30 : 50)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            Divider()

            if settings.effect == .spectrograph {
                SettingsRow(title: "Bars") {
                    Stepper("\(settings.barCount)", value: $settings.barCount, in: MediaActivitySettings.barCountRange)
                }
            }

            if settings.effect == .gif {
                SettingsRow(title: "GIF") {
                    HStack {
                        Text(settings.gifURL?.lastPathComponent ?? "None").foregroundStyle(.secondary)
                        Button("Choose…", action: chooseGIF)
                    }
                }
                SettingsRow(title: "GIF scale") {
                    Slider(value: $settings.gifScale, in: MediaActivitySettings.gifScaleRange).frame(width: 180)
                }
            }

            if settings.effect.isAudioReactive {
                SettingsRow(
                    title: "React to the audio playing",
                    info: "Uses the player's real audio. Asks for System Audio Recording once; without it the effect uses simulated motion."
                ) {
                    Toggle("", isOn: $settings.usesSystemAudio).labelsHidden().toggleStyle(.switch)
                }
                if case let .failed(message) = spectrum.status {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.vertical, 6)
                }
                SettingsRow(title: "Color effects", info: "Tints the effect with the album artwork's color.", showsDivider: false) {
                    Toggle("", isOn: $settings.tintsWithArtwork).labelsHidden().toggleStyle(.switch)
                }
            }
        }
    }

    private func effectPreview(_ effect: MediaEffect) -> some View {
        MediaEffectView(
            effect: effect,
            barCount: settings.barCount,
            tint: settings.tintsWithArtwork ? .pink : .white,
            gifURL: settings.gifURL,
            gifScale: settings.gifScale,
            isPlaying: true
        ) { count, time in
            SimulatedLevels.levels(count: count, time: time)
        }
    }

    private func chooseGIF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.gifURL = url
    }
}

// MARK: - Battery

private struct BatteryActivitySection: View {
    @Bindable var settings: ActivitySettings
    let center: LiveActivityCenter
    /// Changing the id recreates the preview, replaying its entrance animation.
    @State private var replay = 0

    var body: some View {
        SettingsSection(title: "Battery", systemImage: "bolt.fill", accessory: {
            ShowInNotchButton {
                replay += 1
                center.present(.power(.pluggedIn, PreviewSamples.battery))
            }
        }) {
            ClosedNotchPreview {
                PowerActivityLeadingView(event: .pluggedIn, reading: PreviewSamples.battery)
            } trailing: {
                PowerActivityTrailingView(event: .pluggedIn, reading: PreviewSamples.battery)
            }
            .id(replay)
            .onTapGesture { replay += 1 }
            .padding(.bottom, 12)

            SettingsRow(title: "Show when connecting power") {
                Toggle("", isOn: $settings.showsOnPlugIn).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Show when disconnecting power") {
                Toggle("", isOn: $settings.showsOnUnplug).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Show when fully charged") {
                Toggle("", isOn: $settings.showsWhenFull).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Show low battery warning") {
                Toggle("", isOn: $settings.showsLowBattery).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Low battery threshold", info: "The warning shows once when the battery drops to this level.", showsDivider: false) {
                HStack {
                    Text(settings.lowBatteryThreshold, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                    Slider(value: $settings.lowBatteryThreshold, in: ActivitySettings.lowBatteryRange, step: 0.05)
                        .frame(width: 180)
                }
                .disabled(!settings.showsLowBattery)
            }
        }
    }
}

// MARK: - Bluetooth

private struct BluetoothActivitySection: View {
    @Bindable var settings: ActivitySettings
    let monitor: BluetoothMonitor
    let center: LiveActivityCenter
    @State private var replay = 0

    var body: some View {
        SettingsSection(title: "AirPods & Bluetooth", systemImage: "airpods", accessory: {
            ShowInNotchButton {
                replay += 1
                center.present(.bluetooth(PreviewSamples.airpods))
            }
        }) {
            ClosedNotchPreview {
                BluetoothActivityLeadingView(device: PreviewSamples.airpods)
            } trailing: {
                BluetoothActivityTrailingView(device: PreviewSamples.airpods)
            }
            .id(replay)
            .padding(.bottom, 12)

            SettingsRow(title: "Show when devices connect or disconnect", info: "AirPods show the lowest earbud battery.", showsDivider: monitor.lastError != nil) {
                Toggle("", isOn: $settings.showsBluetooth).labelsHidden().toggleStyle(.switch)
            }
            if let error = monitor.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Downloads

private struct DownloadsActivitySection: View {
    @Bindable var settings: ActivitySettings
    let monitor: DownloadsMonitor
    let center: LiveActivityCenter

    var body: some View {
        SettingsSection(title: "Downloads", systemImage: "arrow.down.circle", accessory: {
            ShowInNotchButton {
                center.present(.download(PreviewSamples.download))
            }
        }) {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                // Loops 0...100% every 4 seconds to show the ring filling.
                let fraction = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
                ClosedNotchPreview {
                    DownloadActivityLeadingView(fraction: fraction)
                } trailing: {
                    DownloadActivityTrailingView(fraction: fraction)
                }
            }
            .padding(.bottom, 12)

            SettingsRow(
                title: "Show downloads in progress",
                info: "Follows files that Safari and Chromium browsers download into your Downloads folder.",
                showsDivider: monitor.lastError != nil
            ) {
                Toggle("", isOn: $settings.showsDownloads).labelsHidden().toggleStyle(.switch)
            }
            if let error = monitor.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Calendar

private struct CalendarActivitySection: View {
    @Bindable var settings: ActivitySettings
    let calendar: CalendarStore
    let center: LiveActivityCenter

    var body: some View {
        SettingsSection(title: "Upcoming events", systemImage: "calendar", accessory: {
            ShowInNotchButton {
                center.present(.upcomingEvent(PreviewSamples.upcomingEvent(leadMinutes: settings.calendarLeadMinutes)), for: .seconds(6))
            }
        }) {
            ClosedNotchPreview {
                UpcomingEventLeadingView()
            } trailing: {
                UpcomingEventTrailingView(event: PreviewSamples.upcomingEvent(leadMinutes: settings.calendarLeadMinutes))
            }
            .padding(.bottom, 12)

            SettingsRow(title: "Remind me before events") {
                Toggle("", isOn: $settings.showsUpcomingEvents).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "How long before", showsDivider: calendar.access != .granted) {
                Picker("", selection: $settings.calendarLeadMinutes) {
                    ForEach(ActivitySettings.calendarLeadOptions, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
                .disabled(!settings.showsUpcomingEvents)
            }
            switch calendar.access {
            case .granted:
                EmptyView()
            case .notDetermined:
                HStack {
                    Text("Needs access to your calendars.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Allow access") { calendar.requestAccess() }
                }
                .padding(.top, 10)
            case .unavailable:
                HStack {
                    Text("Calendar access is off.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Open System Settings") { calendar.openPrivacySettings() }
                }
                .padding(.top, 10)
            }
        }
    }
}
