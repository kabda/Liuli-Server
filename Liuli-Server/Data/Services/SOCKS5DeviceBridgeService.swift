import Foundation
import OSLog

/// Service that bridges SOCKS5 connections to device monitoring
/// This service listens to SOCKS5 connection events and updates the device monitor
public actor SOCKS5DeviceBridgeService {
    private let socks5Repository: SOCKS5ServerRepository
    private let deviceMonitor: DeviceMonitorRepository
    private var monitoringTask: Task<Void, Never>?

    // Track connections by source IP
    private var activeConnections: [String: UUID] = [:]

    public init(
        socks5Repository: SOCKS5ServerRepository,
        deviceMonitor: DeviceMonitorRepository
    ) {
        self.socks5Repository = socks5Repository
        self.deviceMonitor = deviceMonitor
    }

    /// Start monitoring SOCKS5 connections and bridging them to device monitor
    public func startMonitoring() {
        // Cancel existing task if any
        monitoringTask?.cancel()

        monitoringTask = Task { [weak self] in
            guard let self = self else { return }

            let stream = await self.socks5Repository.observeConnections()

            for await connection in stream {
                await self.handleSOCKS5Connection(connection)
            }
        }

        Logger.bridge.info("SOCKS5-to-Device bridge service started")
    }

    /// Stop monitoring
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        Logger.bridge.info("SOCKS5-to-Device bridge service stopped")
    }

    // MARK: - Private Methods

    private func handleSOCKS5Connection(_ socks5Connection: SOCKS5Connection) async {
        let sourceIP = socks5Connection.sourceIP

        // Check if this is a new connection from this IP
        if activeConnections[sourceIP] != nil {
            // Update existing device's traffic stats
            Logger.bridge.debug("Updating existing device connection: \(sourceIP)")
            // Note: In a real implementation, you'd track per-connection stats
        } else {
            // New device connection
            let deviceId = UUID()
            activeConnections[sourceIP] = deviceId

            // Create device connection in an isolated context
            await MainActor.run {
                let deviceConnection = DeviceConnection(
                    id: deviceId,
                    deviceName: extractDeviceName(from: sourceIP),
                    connectedAt: socks5Connection.startTime,
                    status: .active,
                    bytesSent: 0,
                    bytesReceived: 0
                )

                Task {
                    await deviceMonitor.addConnection(deviceConnection)
                }
            }

            Logger.bridge.info("New device connected: \(sourceIP)")
        }
    }

    /// Extract device name from IP address
    /// In a real implementation, this would use mDNS/Bonjour to get actual device names
    nonisolated private func extractDeviceName(from ipAddress: String) -> String {
        // For now, just use the last octet of the IP
        if let lastOctet = ipAddress.split(separator: ".").last {
            return "iOS Device (\(lastOctet))"
        }
        return "Unknown Device"
    }
}
