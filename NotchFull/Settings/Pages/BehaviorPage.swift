import SwiftUI

struct BehaviorPage: View {
    @Bindable var behavior: BehaviorSettings

    var body: some View {
        SettingsPage(pane: .behavior) {
            SettingsSection(title: "Notch") {
                SettingsRow(title: "Open on hover", info: "Off: hovering highlights the notch and a click opens it.") {
                    toggle($behavior.opensOnHover)
                }
                SettingsRow(title: "Haptic feedback", info: "A light tap on Force Touch trackpads when the notch opens and on gestures.", showsDivider: false) {
                    toggle($behavior.haptics)
                }
            }

            SettingsSection(title: "Typing") {
                SettingsRow(
                    title: "Keep open while typing",
                    info: "While a text field in the notch has focus, moving the pointer away does not close it.",
                    showsDivider: false
                ) {
                    toggle($behavior.keepsOpenWhileTyping)
                }
            }

            SettingsSection(title: "Gestures", info: "Two-finger swipes on the trackpad while the pointer is over the notch.") {
                SettingsRow(title: "Allow gestures over the notch") {
                    toggle($behavior.gesturesEnabled)
                }
                Group {
                    SettingsRow(title: "Open and close with vertical swipes", info: "Swipe down over the closed notch to open it, up over its top to close it.") {
                        toggle($behavior.verticalGestures)
                    }
                    SettingsRow(title: "Control music with horizontal swipes", info: "Over the closed notch: swipe left for the next track, right for the previous one.") {
                        toggle($behavior.horizontalMediaGestures)
                    }
                    SettingsRow(title: "Invert music gestures", showsDivider: false) {
                        toggle($behavior.invertsMediaGestures)
                            .disabled(!behavior.horizontalMediaGestures)
                    }
                }
                .disabled(!behavior.gesturesEnabled)
            }
        }
    }

    private func toggle(_ isOn: Binding<Bool>) -> some View {
        Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch)
    }
}
