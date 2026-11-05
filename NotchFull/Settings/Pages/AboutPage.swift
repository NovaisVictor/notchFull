import SwiftUI

struct AboutPage: View {
    private static let repositoryURL = URL(string: "https://github.com/NovaisVictor/notchFull")
    private static let releasesURL = URL(string: "https://github.com/NovaisVictor/notchFull/releases")

    var body: some View {
        SettingsPage(pane: .about) {
            SettingsSection(title: "NotchFull") {
                SettingsRow(title: "Version") {
                    Text(Self.version)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                SettingsRow(title: "Updates", info: "Installed with Homebrew? Run `brew upgrade --cask notchfull`.") {
                    if let url = Self.releasesURL {
                        Link("See releases", destination: url)
                    }
                }
                SettingsRow(title: "Source code", showsDivider: false) {
                    if let url = Self.repositoryURL {
                        Link("GitHub", destination: url)
                    }
                }
            }
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return "\(short) (\(build))"
    }
}
