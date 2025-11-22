import SwiftUI

/// Menu bar dropdown view (FR-026)
public struct MenuBarView: View {
    @Bindable var viewModel: MenuBarViewModel

    public init(viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status section
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.state.statusText)
                    .font(.headline)

                if viewModel.state.serviceState == .running {
                    Text("\(viewModel.state.connectedDeviceCount) devices connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            Divider()

            // Actions
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.state.serviceState == .idle || viewModel.state.serviceState == .error {
                    MenuButton(
                        title: "menu.startService".localized(),
                        action: { viewModel.send(.startService) }
                    )
                } else if viewModel.state.serviceState == .running {
                    MenuButton(
                        title: "menu.stopService".localized(),
                        action: { viewModel.send(.stopService) }
                    )
                }

                MenuButton(
                    title: "menu.openCharles".localized(),
                    action: { viewModel.send(.openCharles) }
                )

                MenuButton(
                    title: "menu.viewStatistics".localized(),
                    action: { viewModel.send(.viewStatistics) }
                )

                Divider()
                    .padding(.vertical, 4)

                MenuButton(
                    title: "menu.preferences".localized(),
                    action: { viewModel.send(.openPreferences) }
                )

                MenuButton(
                    title: "menu.quit".localized(),
                    action: { viewModel.send(.quit) }
                )
            }
        }
        .padding(.vertical, 8)
        .frame(width: 250)
    }
}

/// Menu button component
struct MenuButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .hoverEffect()
    }
}

#Preview {
    MenuBarView(
        viewModel: MenuBarViewModel(
            startServiceUseCase: StartServiceUseCase(
                socks5Repository: NIOSwiftSOCKS5ServerRepository(),
                bonjourRepository: NetServiceBonjourRepository(),
                charlesRepository: ProcessCharlesRepository(),
                configRepository: UserDefaultsConfigRepository()
            ),
            stopServiceUseCase: StopServiceUseCase(
                socks5Repository: NIOSwiftSOCKS5ServerRepository(),
                bonjourRepository: NetServiceBonjourRepository()
            ),
            detectCharlesUseCase: DetectCharlesUseCase(
                charlesRepository: ProcessCharlesRepository()
            )
        )
    )
}
