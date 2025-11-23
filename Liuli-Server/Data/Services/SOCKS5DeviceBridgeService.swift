import Foundation
import OSLog

/// Service that bridges SOCKS5 connections to device monitoring
/// This service listens to SOCKS5 connection events and updates the device monitor
/// Also manages Bonjour broadcasting for LAN auto-discovery
public actor SOCKS5DeviceBridgeService {
    private let socks5Repository: SOCKS5ServerRepository
    private let deviceMonitor: DeviceMonitorRepository
    private let broadcastRepository: BonjourBroadcastRepositoryProtocol?
    private let certificateGenerator: CertificateGenerator?
    private let loggingService: LoggingServiceProtocol
    private var monitoringTask: Task<Void, Never>?

    // Track connections by source IP (device ID)
    private var activeConnections: [String: UUID] = [:]
    // Track all SOCKS5 connection IDs per source IP
    private var ipToConnections: [String: Set<UUID>] = [:]
    // Track traffic per connection ID
    private var connectionTraffic: [UUID: (bytesSent: Int64, bytesReceived: Int64)] = [:]
    // Track pending removal tasks (grace period before removing device)
    private var removalTasks: [String: Task<Void, Never>] = [:]
    // Grace period before removing device (30 seconds)
    private let removalGracePeriod: Duration = .seconds(30)

    // Bridge configuration for broadcasting
    private let deviceName: String
    private let deviceID: UUID
    private let proxyPort: Int

    public init(
        socks5Repository: SOCKS5ServerRepository,
        deviceMonitor: DeviceMonitorRepository,
        broadcastRepository: BonjourBroadcastRepositoryProtocol? = nil,
        certificateGenerator: CertificateGenerator? = nil,
        loggingService: LoggingServiceProtocol,
        deviceName: String = Host.current().localizedName ?? "Liuli-Server",
        deviceID: UUID = UUID(),
        proxyPort: Int = 9050
    ) {
        self.socks5Repository = socks5Repository
        self.deviceMonitor = deviceMonitor
        self.broadcastRepository = broadcastRepository
        self.certificateGenerator = certificateGenerator
        self.loggingService = loggingService
        self.deviceName = deviceName
        self.deviceID = deviceID
        self.proxyPort = proxyPort
    }

    /// Start monitoring SOCKS5 connections and bridging them to device monitor
    /// Also starts Bonjour broadcasting if configured
    public func startMonitoring() async throws {
        // Cancel existing task if any
        monitoringTask?.cancel()

        // Start Bonjour broadcasting (if configured)
        if let broadcastRepository = broadcastRepository,
           let certificateGenerator = certificateGenerator {
            await loggingService.logInfo(
                component: "Bridge",
                message: "Starting Bonjour broadcast"
            )

            // Generate or load certificate
            let (_, certificateHash) = try await certificateGenerator.generateSelfSignedCertificate()

            // Create broadcast configuration
            let config = ServiceBroadcast(
                deviceName: deviceName,
                deviceID: deviceID,
                port: proxyPort,
                bridgeStatus: .active,
                certificateHash: certificateHash
            )

            // Start broadcasting
            try await broadcastRepository.startBroadcasting(config: config)

            await loggingService.logInfo(
                component: "Bridge",
                message: "Bonjour broadcast started"
            )
        }

        monitoringTask = Task { [weak self] in
            guard let self = self else { return }

            let stream = await self.socks5Repository.observeConnections()

            for await connection in stream {
                await self.handleSOCKS5Connection(connection)
            }
        }

        Logger.bridge.info("SOCKS5-to-Device bridge service started")
    }

    /// Stop monitoring and stop Bonjour broadcasting
    public func stopMonitoring() async throws {
        monitoringTask?.cancel()
        monitoringTask = nil

        // Stop Bonjour broadcasting (if configured)
        if let broadcastRepository = broadcastRepository {
            await loggingService.logInfo(
                component: "Bridge",
                message: "Stopping Bonjour broadcast"
            )

            try await broadcastRepository.stopBroadcasting()

            await loggingService.logInfo(
                component: "Bridge",
                message: "Bonjour broadcast stopped"
            )
        }

        Logger.bridge.info("SOCKS5-to-Device bridge service stopped")
    }

    /// Update bridge status in TXT record (e.g., active/inactive)
    public func updateBridgeStatus(_ status: ServiceBroadcast.BridgeStatus) async throws {
        guard let broadcastRepository = broadcastRepository else {
            await loggingService.logWarning(
                component: "Bridge",
                message: "Cannot update bridge status - broadcast not configured"
            )
            return
        }

        await loggingService.logInfo(
            component: "Bridge",
            message: "Updating bridge status to \(status.rawValue)"
        )

        try await broadcastRepository.updateBridgeStatus(status)

        await loggingService.logInfo(
            component: "Bridge",
            message: "Bridge status updated successfully"
        )
    }

    // MARK: - Private Methods

    private func handleSOCKS5Connection(_ socks5Connection: SOCKS5Connection) async {
        let sourceIP = socks5Connection.sourceIP

        Logger.bridge.info("📥 Received SOCKS5 event: IP=\(sourceIP), state=\(String(describing: socks5Connection.state))")

        // Check connection state
        if socks5Connection.state == .closed {
            // Remove this connection from tracking
            ipToConnections[sourceIP]?.remove(socks5Connection.id)
            connectionTraffic.removeValue(forKey: socks5Connection.id)

            let remainingCount = ipToConnections[sourceIP]?.count ?? 0

            Logger.bridge.info("📊 Connection count for \(sourceIP): \(remainingCount + 1) -> \(remainingCount)")

            if remainingCount == 0 {
                // All connections closed, schedule removal after grace period
                ipToConnections.removeValue(forKey: sourceIP)
                scheduleDeviceRemoval(sourceIP: sourceIP)
            } else {
                // Still have active connections, update traffic
                if let deviceId = activeConnections[sourceIP] {
                    let totalTraffic = calculateTotalTraffic(for: sourceIP)
                    await deviceMonitor.updateTrafficStatistics(
                        deviceId,
                        bytesSent: totalTraffic.bytesSent,
                        bytesReceived: totalTraffic.bytesReceived
                    )
                }
                Logger.bridge.debug("Connection closed from \(sourceIP), \(remainingCount) remaining")
            }
            return
        }

        // Update traffic tracking for this specific connection
        connectionTraffic[socks5Connection.id] = (
            bytesSent: Int64(socks5Connection.bytesUploaded),
            bytesReceived: Int64(socks5Connection.bytesDownloaded)
        )

        // New or existing connection from this IP
        if let existingDeviceId = activeConnections[sourceIP] {
            // Add this connection to the IP's connection set
            ipToConnections[sourceIP, default: []].insert(socks5Connection.id)

            // Cancel pending removal task (device reconnected)
            if let removalTask = removalTasks[sourceIP] {
                removalTask.cancel()
                removalTasks.removeValue(forKey: sourceIP)
                Logger.bridge.info("🔄 Device reconnected before removal: \(sourceIP)")
            }

            // Update traffic statistics for existing device
            let totalTraffic = calculateTotalTraffic(for: sourceIP)
            await deviceMonitor.updateTrafficStatistics(
                existingDeviceId,
                bytesSent: totalTraffic.bytesSent,
                bytesReceived: totalTraffic.bytesReceived
            )

            let connectionCount = ipToConnections[sourceIP]?.count ?? 0
            Logger.bridge.info("📊 Connection from device: \(sourceIP), total connections: \(connectionCount)")
        } else {
            // New device connection
            let deviceId = UUID()
            activeConnections[sourceIP] = deviceId
            ipToConnections[sourceIP] = [socks5Connection.id]

            let totalTraffic = calculateTotalTraffic(for: sourceIP)

            // Create device connection and add to monitor
            let deviceConnection = DeviceConnection(
                id: deviceId,
                deviceName: extractDeviceName(from: sourceIP),
                connectedAt: socks5Connection.startTime,
                status: .active,
                bytesSent: totalTraffic.bytesSent,
                bytesReceived: totalTraffic.bytesReceived
            )

            // Add to device monitor (actor-isolated call)
            await deviceMonitor.addConnection(deviceConnection)

            Logger.bridge.info("✅ New device connected: \(sourceIP), initial connections: 1")
        }
    }

    /// Calculate total traffic for all connections from a specific IP
    private func calculateTotalTraffic(for sourceIP: String) -> (bytesSent: Int64, bytesReceived: Int64) {
        guard let connectionIDs = ipToConnections[sourceIP] else {
            return (bytesSent: 0, bytesReceived: 0)
        }

        var totalSent: Int64 = 0
        var totalReceived: Int64 = 0

        for connectionID in connectionIDs {
            if let traffic = connectionTraffic[connectionID] {
                totalSent += traffic.bytesSent
                totalReceived += traffic.bytesReceived
            }
        }

        return (bytesSent: totalSent, bytesReceived: totalReceived)
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
