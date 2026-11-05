import AppKit
import ImageIO
import SwiftUI

struct ScreensPage: View {
    @Bindable var settings: ScreenSettings
    @State private var displays = DisplayInfo.connected()

    var body: some View {
        SettingsPage(pane: .screens) {
            displaysSection
            fullscreenSection
            handleSection
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = DisplayInfo.connected()
        }
    }

    private var displaysSection: some View {
        let enabledCount = displays.filter { settings.isEnabled($0.uuid) }.count

        return SettingsSection(title: "Show NotchFull on", info: "Choose which screens show the notch. Your choice is kept when a screen is reconnected.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], alignment: .leading, spacing: 14) {
                ForEach(displays) { display in
                    DisplayCard(display: display, isEnabled: settings.isEnabled(display.uuid)) {
                        settings.setEnabled(!settings.isEnabled(display.uuid), uuid: display.uuid, connected: displays.map(\.uuid))
                    }
                }
            }

            HStack {
                Text("On \(enabledCount) of \(displays.count) screens.")
                    .foregroundStyle(enabledCount == 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                Spacer()
                Button("All screens") { settings.enableAll() }
                    .buttonStyle(.link)
                Text("·").foregroundStyle(.secondary)
                Button("Only screens with a notch") {
                    settings.enableOnly(displays.filter(\.hasNotch).map(\.uuid))
                }
                .buttonStyle(.link)
                .disabled(!displays.contains(where: \.hasNotch))
            }
            .font(.caption)
            .padding(.top, 12)
        }
    }

    private var fullscreenSection: some View {
        SettingsSection(title: "Full screen", info: "What happens when an app is in full screen.") {
            HStack(spacing: 12) {
                ForEach(FullscreenPolicy.allCases) { policy in
                    ChoiceTile(
                        title: policy.title,
                        subtitle: policy.summary,
                        systemImage: policy.systemImage,
                        isSelected: settings.fullscreenPolicy == policy
                    ) {
                        settings.fullscreenPolicy = policy
                    }
                }
            }
        }
    }

    private var handleSection: some View {
        SettingsSection(title: "Screens without a notch", info: "On these screens a small handle marks where the notch opens.") {
            HandlePreview(settings: settings)
                .padding(.bottom, 12)

            SettingsRow(title: "Show handle", info: "Off leaves the area invisible; hovering it still opens the notch.") {
                Toggle("", isOn: $settings.showsHandle).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Width") {
                valueSlider(value: $settings.handleWidth, range: ScreenSettings.handleWidthRange)
            }
            SettingsRow(title: "Height") {
                valueSlider(value: $settings.handleHeight, range: ScreenSettings.handleHeightRange)
            }
            SettingsRow(title: "Transparent handle", info: "A translucent bar instead of a black one.", showsDivider: false) {
                Toggle("", isOn: $settings.handleIsTransparent).labelsHidden().toggleStyle(.switch)
                    .disabled(!settings.showsHandle)
            }
        }
    }

    private func valueSlider(value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            Slider(value: value, in: range, step: 1)
                .frame(width: 200)
            Text("\(Int(value.wrappedValue))")
                .monospacedDigit()
                .frame(width: 36)
                .padding(.vertical, 3)
                .background(.quaternary, in: .rect(cornerRadius: 6))
        }
    }
}

private struct DisplayCard: View {
    let display: DisplayInfo
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 10) {
                WallpaperThumbnail(url: display.wallpaperURL)
                    .aspectRatio(display.size.width / max(display.size.height, 1), contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 6, style: .continuous))
                    .overlay(alignment: .top) {
                        if display.hasNotch {
                            UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)
                                .fill(.black)
                                .frame(width: 26, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(display.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(display.traits).font(.caption).foregroundStyle(.secondary)
                        Text("\(Int(display.size.width)) × \(Int(display.size.height))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17))
                        .foregroundStyle(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
            }
            .padding(12)
            .background(.background.tertiary, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(0.08)), lineWidth: isEnabled ? 2 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.15), value: isEnabled)
    }
}

/// The display's wallpaper, downsampled off the main thread; wallpapers can be several thousand pixels wide.
private struct WallpaperThumbnail: View {
    let url: URL?
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                WallpaperBackdrop()
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            image = await Self.thumbnail(for: url)
        }
    }

    private static func thumbnail(for url: URL) async -> NSImage? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 480,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            // Dynamic wallpapers and folders are not plain images; the backdrop stands in for them.
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return NSImage(cgImage: cgImage, size: .zero)
        }.value
    }
}

/// The handle as it looks at the top of a screen without a notch.
private struct HandlePreview: View {
    let settings: ScreenSettings

    var body: some View {
        ZStack(alignment: .top) {
            WallpaperBackdrop()
            Rectangle()
                .fill(.black.opacity(0.35))
                .frame(height: 22)
            if settings.showsHandle {
                UnevenRoundedRectangle(
                    bottomLeadingRadius: settings.handleHeight / 2,
                    bottomTrailingRadius: settings.handleHeight / 2,
                    style: .continuous
                )
                .fill(settings.handleIsTransparent ? Color.white.opacity(0.28) : .black)
                .frame(width: settings.handleWidth, height: settings.handleHeight)
            }
        }
        .frame(height: 70)
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .animation(.smooth(duration: 0.15), value: settings.handleWidth)
        .animation(.smooth(duration: 0.15), value: settings.handleHeight)
    }
}

/// A selectable tile with an icon, title and one-line explanation.
struct ChoiceTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .rect(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.tertiary, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(0.08)), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.15), value: isSelected)
    }
}
