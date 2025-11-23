import Foundation
import SwiftUI

/// Aggregate state for main dashboard window
public struct DashboardState: Sendable, Equatable {
    /// List of connected devices (from MonitorDeviceConnectionsUseCase)
    public var devices: [DeviceConnection]

    /// Network bridge status (from MonitorNetworkStatusUseCase)
    public var networkStatus: NetworkStatus

    /// Charles proxy status (from CheckCharlesAvailabilityUseCase)
    public var charlesStatus: CharlesStatus

    /// Loading indicator (during initial data fetch)
    public var isLoading: Bool

    /// Refreshing indicator (during manual refresh)
    public var isRefreshing: Bool

    /// Selected device ID (for detail view, future feature)
    public var selectedDeviceId: UUID?

    /// Error message if monitoring fails
    public var errorMessage: String?

    public init(
        devices: [DeviceConnection] = [],
        networkStatus: NetworkStatus = NetworkStatus(isListening: false),
        charlesStatus: CharlesStatus = CharlesStatus(
            availability: .unknown,
            proxyHost: "localhost",
            proxyPort: 8888
        ),
        isLoading: Bool = false,
        isRefreshing: Bool = false,
        selectedDeviceId: UUID? = nil,
        errorMessage: String? = nil
    ) {
        self.devices = devices
        self.networkStatus = networkStatus
        self.charlesStatus = charlesStatus
        self.isLoading = isLoading
        self.isRefreshing = isRefreshing
        self.selectedDeviceId = selectedDeviceId
        self.errorMessage = errorMessage
    }
}

/// ViewModel for main dashboard window
@MainActor
@Observable
public final class DashboardViewModel {
    private let monitorDevicesUseCase: MonitorDeviceConnectionsUseCase
    private let monitorNetworkUseCase: MonitorNetworkStatusUseCase
    private let checkCharlesUseCase: CheckCharlesAvailabilityUseCase

    private(set) var state = DashboardState()

    private var devicesTask: Task<Void, Never>?
    private var networkTask: Task<Void, Never>?
    private var charlesTask: Task<Void, Never>?

    public init(
        monitorDevicesUseCase: MonitorDeviceConnectionsUseCase,
        monitorNetworkUseCase: MonitorNetworkStatusUseCase,
        checkCharlesUseCase: CheckCharlesAvailabilityUseCase
    ) {
        self.monitorDevicesUseCase = monitorDevicesUseCase
        self.monitorNetworkUseCase = monitorNetworkUseCase
        self.checkCharlesUseCase = checkCharlesUseCase
    }

    public func startMonitoring() {
        state.errorMessage = nil

        // Monitor devices with error handling
        devicesTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                for await devices in self.monitorDevicesUseCase.execute() {
                    await MainActor.run {
                        self.state.devices = devices
                    }
                }
            } catch {
                await MainActor.run {
                    self.state.errorMessage = "Device monitoring error: \(error.localizedDescription)"
                    Logger.ui.error("Device monitoring failed: \(error)")
                }
            }
        }

        // Monitor network status with error handling
        networkTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                for await status in self.monitorNetworkUseCase.execute() {
                    await MainActor.run {
                        self.state.networkStatus = status
                    }
                }
            } catch {
                await MainActor.run {
                    self.state.errorMessage = "Network monitoring error: \(error.localizedDescription)"
                    Logger.ui.error("Network monitoring failed: \(error)")
                }
            }
        }

        // Monitor Charles availability with error handling
        charlesTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                for await status in self.checkCharlesUseCase.execute() {
                    await MainActor.run {
                        self.state.charlesStatus = status
                    }
                }
            } catch {
                await MainActor.run {
                    self.state.errorMessage = "Charles monitoring error: \(error.localizedDescription)"
                    Logger.ui.error("Charles monitoring failed: \(error)")
                }
            }
        }
    }

    public func stopMonitoring() {
        devicesTask?.cancel()
        networkTask?.cancel()
        charlesTask?.cancel()
    }

    /// Manually refresh all monitoring data
    public func refresh() async {
        state.isRefreshing = true

        // Cancel existing tasks
        stopMonitoring()

        // Add a small delay to make the animation visible
        try? await Task.sleep(for: .milliseconds(500))

        // Restart monitoring
        startMonitoring()

        state.isRefreshing = false
    }
}
