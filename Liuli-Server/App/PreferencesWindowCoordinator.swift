import AppKit
import SwiftUI

/// Preferences window coordinator
@MainActor
public final class PreferencesWindowCoordinator {
    private var window: NSWindow?
    private let viewModel: PreferencesViewModel

    public init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel
    }

    public func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "preferences.title".localized()
        window.center()
        window.contentView = NSHostingView(
            rootView: PreferencesView(viewModel: viewModel)
        )

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    public func close() {
        window?.close()
        window = nil
    }
}
