import SwiftUI

/// The volume HUD: whether it replaces the system one, the Accessibility permission it needs and its style.
struct HUDPage: View {
    @Bindable var settings: HUDSettings
    let hud: VolumeHUD

    var body: some View {
        SettingsPage(pane: .hud) {
            VolumeSection(settings: settings, hud: hud, keyTap: hud.keyTap)
            StyleSection(settings: settings)
            SettingsSection(title: "Brightness", systemImage: "sun.max.fill") {
                Text("Brightness keys keep the system indicator. macOS has no public API to change the built-in display's brightness, and NotchFull does not use private ones.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Volume

private struct VolumeSection: View {
    @Bindable var settings: HUDSettings
    let hud: VolumeHUD
    let keyTap: MediaKeyTap

    var body: some View {
        SettingsSection(title: "Volume", systemImage: "speaker.wave.2.fill", accessory: {
            Button("Show in notch", systemImage: "play.circle") {
                hud.show(PreviewSamples.volume)
            }
            .controlSize(.small)
        }) {
            VolumeHUDPreview(state: PreviewSamples.volume, style: settings.style)
                .frame(height: 96)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 12)

            SettingsRow(title: "Replace the volume HUD", info: "Volume up, volume down and mute. Option-Shift changes the volume in fine steps.") {
                Toggle("", isOn: $settings.replacesVolume).labelsHidden().toggleStyle(.switch)
            }
            .onChange(of: settings.replacesVolume) { _, replaces in
                if replaces, !keyTap.isTrusted {
                    keyTap.requestAccess()
                }
            }

            SettingsRow(
                title: "Accessibility",
                info: "NotchFull reads the volume keys before macOS so the system indicator stays hidden. Without this permission the keys work as usual.",
                showsDivider: false
            ) {
                if keyTap.isTrusted {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        Button("Request Access") { keyTap.requestAccess() }
                        Button("Open System Settings") { keyTap.openAccessibilitySettings() }
                    }
                }
            }

            ForEach([keyTap.lastError, hud.lastError].compactMap(\.self), id: \.self) { error in
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
            if let reason = hud.passThroughReason {
                Label(reason, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Style

private struct StyleSection: View {
    @Bindable var settings: HUDSettings

    var body: some View {
        SettingsSection(title: "Style", systemImage: "rectangle.topthird.inset.filled") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(HUDStyle.allCases) { style in
                    OptionCard(title: style.displayName, subtitle: subtitle(style), isSelected: settings.style == style) {
                        settings.style = style
                    } preview: {
                        VolumeHUDPreview(state: PreviewSamples.volume, style: style, scale: 0.7)
                    }
                }
            }
        }
    }

    private func subtitle(_ style: HUDStyle) -> String {
        switch style {
        case .embedded: "Stays in the notch line."
        case .classic: "Grows below the notch."
        }
    }
}

/// The closed notch showing the volume HUD in a style, on a wallpaper strip; scaled down to fit option cards.
private struct VolumeHUDPreview: View {
    let state: VolumeState
    let style: HUDStyle
    var scale: CGFloat = 1

    var body: some View {
        let closedSize = PreviewMetrics.closedSize
        let activity = LiveActivityCenter.Activity.volume(state, style: style)
        let side = activity.sideWidth(closedHeight: closedSize.height)
        let below = activity.heightBelowNotch

        // An overlay does not take part in layout, so the full-width notch never widens the card it sits in.
        WallpaperBackdrop()
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    ClosedNotchSlots(closedSize: closedSize, sideWidth: side) {
                        if style == .embedded {
                            VolumeEmbeddedLeadingView(state: state)
                        }
                    } trailing: {
                        if style == .embedded {
                            VolumeEmbeddedTrailingView(state: state)
                        }
                    }
                    if below > 0 {
                        VolumeClassicView(state: state)
                            .frame(height: below, alignment: .top)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(width: closedSize.width + side * 2)
                .background {
                    NotchShape(topRadius: 6, bottomRadius: below > 0 ? 16 : 10)
                        .fill(.black)
                        .padding(.horizontal, -6)
                }
                .scaleEffect(scale, anchor: .top)
            }
    }
}

extension PreviewSamples {
    static let volume = VolumeState(level: 0.68, isMuted: false, deviceName: nil)
}
