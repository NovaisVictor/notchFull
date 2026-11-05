import AppKit
import SwiftUI

/// A regular window with the current note, larger than the widget. It edits the same store, so changes show in the
/// notch and in the window as they are typed.
@MainActor
final class NoteWindowController {
    private let store: NoteStore
    private let settings: NotesSettings
    private var window: NSWindow?

    init(store: NoteStore, settings: NotesSettings) {
        self.store = store
        self.settings = settings
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // An agent app is not active while the notch is used; without activating, the window opens behind others.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let content = NoteEditorPane(store: store, settings: settings, textInset: CGSize(width: 6, height: 8), toolbarSpacing: 14)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .foregroundStyle(.white)
            .background(Color(white: 0.11))
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = "Notes"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.setContentSize(CGSize(width: 520, height: 440))
        window.contentMinSize = CGSize(width: 320, height: 220)
        window.center()
        window.setFrameAutosaveName("NoteWindow")
        return window
    }
}
