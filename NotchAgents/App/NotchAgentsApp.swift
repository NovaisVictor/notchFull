import SwiftUI

@main
struct NotchAgentsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("NotchAgents")
                .padding()
        }
    }
}
