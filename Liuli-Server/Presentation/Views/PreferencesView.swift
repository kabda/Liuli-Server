import SwiftUI

/// Preferences window view (FR-028)
public struct PreferencesView: View {
    @Bindable var viewModel: PreferencesViewModel

    public init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                Form {
                    // SOCKS5 Configuration Section
                    Section {
                        HStack {
                            Text("preferences.socks5Port".localized())
                                .frame(width: 150, alignment: .trailing)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                TextField("", value: $viewModel.state.configuration.socks5Port, format: .number.grouping(.never))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)

                                Text("preferences.portRange".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("preferences.bonjourServiceName".localized())
                                .frame(width: 150, alignment: .trailing)

                            Spacer()

                            TextField("", text: $viewModel.state.configuration.bonjourServiceName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 250)
                        }
                    } header: {
                        Text("preferences.section.network".localized())
                            .font(.headline)
                    }

                    // Charles Configuration Section
                    Section {
                        HStack {
                            Text("preferences.charlesProxyHost".localized())
                                .frame(width: 150, alignment: .trailing)

                            Spacer()

                            TextField("", text: $viewModel.state.configuration.charlesHost)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 250)
                        }

                        HStack {
                            Text("preferences.charlesProxyPort".localized())
                                .frame(width: 150, alignment: .trailing)

                            Spacer()

                            TextField("", value: $viewModel.state.configuration.charlesPort, format: .number.grouping(.never))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }

                        HStack {
                            Text("preferences.charlesSSLProxyPort".localized())
                                .frame(width: 150, alignment: .trailing)

                            Spacer()

                            TextField("", value: $viewModel.state.configuration.charlesSSLProxyPort, format: .number.grouping(.never))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    } header: {
                        Text("preferences.section.charles".localized())
                            .font(.headline)
                    }

                    // Advanced Settings Section
                    Section {
                        HStack {
                            Text("preferences.maxRetries".localized())
                                .frame(width: 150, alignment: .trailing)

                            Spacer()

                            Stepper(
                                value: $viewModel.state.configuration.maxRetries,
                                in: 0...10
                            ) {
                                Text("\(viewModel.state.configuration.maxRetries)")
                                    .frame(width: 30)
                            }
                            .frame(width: 100)
                        }

                        HStack {
                            Text("preferences.connectionTimeout".localized())
                                .frame(width: 150, alignment: .trailing)

                            Spacer()

                            HStack(spacing: 8) {
                                Slider(
                                    value: $viewModel.state.configuration.connectionTimeout,
                                    in: 5...60,
                                    step: 5
                                )
                                .frame(width: 200)

                                Text("\(Int(viewModel.state.configuration.connectionTimeout))s")
                                    .frame(width: 40)
                            }
                        }
                    } header: {
                        Text("preferences.section.advanced".localized())
                            .font(.headline)
                    }
                }
                .formStyle(.grouped)
            }
            .scrollIndicators(.hidden)

            // Validation error
            if let error = viewModel.state.validationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // Action buttons
            HStack {
                Button("preferences.resetDefaults".localized()) {
                    viewModel.send(.resetToDefaults)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("preferences.save".localized()) {
                    viewModel.send(.save)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.state.isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .task {
            viewModel.send(.onAppear)
        }
    }
}

#Preview {
    PreferencesView(
        viewModel: PreferencesViewModel(
            manageConfigurationUseCase: ManageConfigurationUseCase(
                configRepository: UserDefaultsConfigRepository()
            )
        )
    )
}
