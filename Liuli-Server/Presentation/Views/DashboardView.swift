import SwiftUI

/// Main dashboard view showing network status and connected devices
public struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    public init(viewModel: DashboardViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status panel (Phase 4)
                StatusPanelView(
                    networkStatus: viewModel.state.networkStatus,
                    charlesStatus: viewModel.state.charlesStatus
                )

                Divider()

                // Device list
                DeviceListView(devices: viewModel.state.devices)
            }
            .navigationTitle("Liuli Server")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Refresh") {
                        // Refresh action
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}
