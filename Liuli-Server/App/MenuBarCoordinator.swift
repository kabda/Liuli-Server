import AppKit
import SwiftUI

/// Menu bar coordinator for managing NSStatusItem (FR-024, FR-025)
@MainActor
public final class MenuBarCoordinator {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let viewModel: MenuBarViewModel

    public init(viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
    }

    public func setup() {
        // Create status item in menu bar
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "" // Will be replaced with icon
            button.action = #selector(togglePopover)
            button.target = self

            // Set initial icon based on state
            updateIcon(for: viewModel.state.serviceState)
        }

        self.statusItem = statusItem

        // Create popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 250, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(viewModel: viewModel)
        )

        self.popover = popover

        // Observe state changes to update icon
        observeStateChanges()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func observeStateChanges() {
        // TODO: Observe viewModel.state changes and update icon
        // For now, this is a placeholder
    }

    private func updateIcon(for state: ServiceState) {
        guard let button = statusItem?.button else { return }

        // TODO: Load actual icon assets from Resources/Assets.xcassets
        // For now, use text-based indicator (FR-025: gray/blue/green/yellow/red)
        let iconMap: [ServiceState: String] = [
            .idle: "⚪️",      // gray
            .starting: "🔵",   // blue
            .running: "🟢",    // green
            .stopping: "🔵",   // blue
            .error: "🔴"       // red
        ]

        button.title = iconMap[state] ?? "⚪️"
    }
}
