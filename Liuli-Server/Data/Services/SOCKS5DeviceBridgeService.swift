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
    // Track connection count per IP (to handle multiple TCP connections from same device)
    private var connectionCounts: [String: Int] = [:]
    // Track pending removal tasks (grace period before removing device)
    private var removalTasks: [String: Task<Void, Never>] = [:]
    // Grace period before removing device (30 seconds)
    private let removalGracePeriod: Duration = .seconds(30)

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

        Logger.bridge.info("📥 Received SOCKS5 event: IP=\(sourceIP), state=\(String(describing: socks5Connection.state))")

        // Check connection state
        if socks5Connection.state == .closed {
            // Decrement connection count for this IP
            let count = (connectionCounts[sourceIP] ?? 1) - 1

            Logger.bridge.info("📊 Connection count for \(sourceIP): \(connectionCounts[sourceIP] ?? 0) -> \(count)")

            if count <= 0 {
                // All connections closed, schedule removal after grace period
                connectionCounts.removeValue(forKey: sourceIP)
                scheduleDeviceRemoval(sourceIP: sourceIP)
            } else {
                // Still have active connections from this IP
                connectionCounts[sourceIP] = count
                Logger.bridge.debug("Connection closed from \(sourceIP), \(count) remaining")
            }
            return
        }

        // New or existing connection from this IP
        if let existingDeviceId = activeConnections[sourceIP] {
            // Cancel pending removal task (device reconnected)
            if let removalTask = removalTasks[sourceIP] {
                removalTask.cancel()
                removalTasks.removeValue(forKey: sourceIP)
                Logger.bridge.info("🔄 Device reconnected before removal: \(sourceIP)")
            }

            // Increment connection count for existing device
            let newCount = (connectionCounts[sourceIP] ?? 0) + 1
            connectionCounts[sourceIP] = newCount
            Logger.bridge.info("📊 Additional connection from existing device: \(sourceIP), count: \(connectionCounts[sourceIP] ?? 0) -> \(newCount)")
        } else {
            // New device connection
            let deviceId = UUID()
            activeConnections[sourceIP] = deviceId
            connectionCounts[sourceIP] = 1

            // Create device connection on MainActor
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

            Logger.bridge.info("✅ New device connected: \(sourceIP), count=1")
        }
    }

    /// Schedule device removal after grace period
    private func scheduleDeviceRemoval(sourceIP: String) {
        // Cancel existing removal task if any
        removalTasks[sourceIP]?.cancel()

        // Schedule new removal task
        removalTasks[sourceIP] = Task { [weak self] in
            guard let self = self else { return }

            do {
                try await Task.sleep(for: removalGracePeriod)

                // Grace period passed, remove device
                await self.performDeviceRemoval(sourceIP: sourceIP)
            } catch {
                // Task was cancelled (device reconnected)
                Logger.bridge.debug("⏹️ Device removal cancelled for \(sourceIP)")
            }
        }

        Logger.bridge.info("⏱️ Scheduled removal for \(sourceIP) in \(removalGracePeriod.components.seconds)s")
    }

    /// Actually remove the device (called after grace period)
    private func performDeviceRemoval(sourceIP: String) async {
        if let deviceId = activeConnections.removeValue(forKey: sourceIP) {
            await deviceMonitor.removeConnection(deviceId)
            removalTasks.removeValue(forKey: sourceIP)
            Logger.bridge.info("❌ Device disconnected after grace period: \(sourceIP)")
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
