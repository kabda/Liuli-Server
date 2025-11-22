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

    /// Selected device ID (for detail view, future feature)
    public var selectedDeviceId: UUID?

    public init(
        devices: [DeviceConnection] = [],
        networkStatus: NetworkStatus = NetworkStatus(isListening: false),
        charlesStatus: CharlesStatus = CharlesStatus(
            availability: .unknown,
            proxyHost: "localhost",
            proxyPort: 8888
        ),
        isLoading: Bool = false,
        selectedDeviceId: UUID? = nil
    ) {
        self.devices = devices
        self.networkStatus = networkStatus
        self.charlesStatus = charlesStatus
        self.isLoading = isLoading
        self.selectedDeviceId = selectedDeviceId
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
        // Monitor devices
        devicesTask = Task {
            for await devices in monitorDevicesUseCase.execute() {
                state.devices = devices
            }
        }

        // Monitor network status
        networkTask = Task {
            for await status in monitorNetworkUseCase.execute() {
                state.networkStatus = status
            }
        }

        // Monitor Charles availability
        charlesTask = Task {
            for await status in checkCharlesUseCase.execute() {
                state.charlesStatus = status
            }
        }
    }

    public func stopMonitoring() {
        devicesTask?.cancel()
        networkTask?.cancel()
        charlesTask?.cancel()
    }
}
