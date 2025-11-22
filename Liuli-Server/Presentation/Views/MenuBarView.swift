import SwiftUI

/// Menu bar dropdown view with bridge toggle control
public struct MenuBarView: View {
    @State private var viewModel: MenuBarViewModel

    public init(viewModel: MenuBarViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with connection count
            VStack(alignment: .leading, spacing: 4) {
                Text("Liuli Server")
                    .font(.headline)

                if viewModel.state.isBridgeEnabled {
                    Text("\(viewModel.state.connectionCount) device(s) connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Bridge disabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()
                .padding(.vertical, 4)

            // Bridge toggle
            Toggle("Enable Bridge", isOn: Binding(
                get: { viewModel.state.isBridgeEnabled },
                set: { newValue in
                    if newValue != viewModel.state.isBridgeEnabled {
                        viewModel.send(.toggleBridge)
                    }
                }
            ))
            .padding(.horizontal, 12)

            Divider()
                .padding(.vertical, 4)

            // Menu actions
            MenuButton("Show Main Window") {
                viewModel.send(.showMainWindow)
            }

            MenuButton("Settings...") {
                viewModel.send(.openSettings)
            }

            Divider()
                .padding(.vertical, 4)

            MenuButton("Quit") {
                viewModel.send(.quit)
            }

            // Error message if any
            if let error = viewModel.state.errorMessage {
                Divider()
                    .padding(.vertical, 4)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 250)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

/// Menu button component
private struct MenuButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
