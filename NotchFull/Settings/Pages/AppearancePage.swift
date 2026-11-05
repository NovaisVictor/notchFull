import SwiftUI

struct AppearancePage: View {
    @Bindable var appearance: AppearanceSettings

    var body: some View {
        SettingsPage(pane: .appearance) {
            SettingsSection(
                title: "Notch style",
                info: "Applies to the open notch. Closed, it stays black to blend with the camera housing."
            ) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 18) {
                    ForEach(NotchStyle.allCases) { style in
                        OptionCard(
                            title: style.displayName,
                            subtitle: style.summary,
                            isSelected: appearance.notchStyle == style,
                            previewHeight: 130
                        ) {
                            appearance.notchStyle = style
                        } preview: {
                            StylePreview(style: style, glassLevel: appearance.glassLevel)
                        }
                    }
                }
                .padding(.bottom, 14)

                SettingsRow(
                    title: "Glass level",
                    info: "How dark smoked glass is. Lower lets more of your wallpaper glow through.",
                    showsDivider: false
                ) {
                    HStack(spacing: 10) {
                        Text("Clear").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $appearance.glassLevel, in: AppearanceSettings.glassLevelRange)
                            .frame(width: 200)
                        Text("Dark").font(.caption).foregroundStyle(.secondary)
                        Button("Default") { appearance.glassLevel = AppearanceSettings.defaultGlassLevel }
                            .controlSize(.small)
                            .disabled(appearance.glassLevel == AppearanceSettings.defaultGlassLevel)
                    }
                }
                .disabled(appearance.notchStyle != .smokedGlass)
            }
        }
    }
}

/// A wide strip with the open notch hanging from the top, like the real screen.
private struct StylePreview: View {
    let style: NotchStyle
    let glassLevel: Double

    var body: some View {
        ZStack(alignment: .top) {
            WallpaperBackdrop()
            NookSkeleton()
                .padding(.top, 14)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .frame(width: 190, height: 92)
                .background {
                    NotchSurface(style: style, glassLevel: glassLevel, shape: NotchShape(topRadius: 9, bottomRadius: 20))
                }
                .environment(\.notchStyle, style)
        }
    }
}
