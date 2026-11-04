import SwiftUI

@main
struct NotchFullApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("NotchFull")
                .padding()
        }
    }
}
