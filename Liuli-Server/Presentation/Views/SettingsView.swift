import SwiftUI

/// Settings window view
public struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: SettingsViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Form {
            // Charles Proxy Section
            Section("Charles Proxy") {
                LabeledContent("Host:") {
                    TextField("localhost", text: Binding(
                        get: { viewModel.state.settings.charlesProxyHost },
                        set: { viewModel.send(.updateCharlesHost($0)) }
                    ))
                    .frame(width: 200)
                }

                LabeledContent("Port:") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("8888", text: Binding(
                            get: { String(viewModel.state.settings.charlesProxyPort) },
                            set: { viewModel.send(.updateCharlesPort($0)) }
                        ))
                        .frame(width: 100)

                        if let error = viewModel.state.portError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            // Behavior Section
            Section("Behavior") {
                Toggle("Auto-start bridge on launch", isOn: Binding(
                    get: { viewModel.state.settings.autoStartBridge },
                    set: { _ in viewModel.send(.toggleAutoStart) }
                ))

                Toggle("Show menu bar icon", isOn: Binding(
                    get: { viewModel.state.settings.showMenuBarIcon },
                    set: { _ in viewModel.send(.toggleShowMenuBarIcon) }
                ))

                Toggle("Show main window on launch", isOn: Binding(
                    get: { viewModel.state.settings.showMainWindowOnLaunch },
                    set: { _ in viewModel.send(.toggleShowMainWindowOnLaunch) }
                ))
            }

            // Error message
            if let error = viewModel.state.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.send(.save)
                }
                .disabled(!viewModel.canSave)
            }
        }
        .onAppear {
            viewModel.send(.load)
        }
        .onChange(of: viewModel.state.saveSucceeded) { _, succeeded in
            if succeeded {
                dismiss()
            }
        }
    }
}
