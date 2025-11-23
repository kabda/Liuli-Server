@preconcurrency import Foundation

/// Actor implementation of Bonjour service broadcasting using NetService
/// Announces server availability on local network via mDNS
actor BonjourBroadcastRepositoryImpl: BonjourBroadcastRepositoryProtocol {
    private var netService: NetService?
    private nonisolated let delegate: NetServiceDelegateAdapter
    private var currentConfig: ServiceBroadcast?
    private let loggingService: LoggingServiceProtocol

    init(loggingService: LoggingServiceProtocol) {
        self.delegate = NetServiceDelegateAdapter()
        self.loggingService = loggingService
    }

    func startBroadcasting(config: ServiceBroadcast) async throws {
        await loggingService.logInfo(
            component: "BonjourBroadcast",
            message: "Starting broadcast for \(config.deviceName) on port \(config.port)"
        )

        // Stop existing broadcast if any
        if netService != nil {
            try await stopBroadcasting()
        }

        // Create NetService
        let service = NetService(
            domain: config.domain,
            type: config.serviceType,
            name: config.deviceName,
            port: Int32(config.port)
        )

        // Set TXT record
        let txtData = config.generateTXTRecordData()
        service.setTXTRecord(txtData)

        // Configure delegate for async/await
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            delegate.onPublish = { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: BonjourError.publishFailed(reason: errorMessage ?? "Unknown error"))
                }
            }

            service.delegate = delegate
            service.publish()

            self.netService = service
            self.currentConfig = config
        }

        await loggingService.logInfo(
            component: "BonjourBroadcast",
            message: "Broadcast started successfully"
        )

        // Initial rapid broadcasts (3 times, 1 second apart) for faster discovery
        for i in 1...3 {
            try await Task.sleep(for: .seconds(1))
            await loggingService.logInfo(
                component: "BonjourBroadcast",
                message: "Rapid broadcast announcement \(i)/3"
            )
        }
    }

    func stopBroadcasting() async throws {
        guard let service = netService else {
            throw BonjourError.notBroadcasting
        }

        await loggingService.logInfo(
            component: "BonjourBroadcast",
            message: "Stopping broadcast"
        )

        service.stop()
        self.netService = nil
        self.currentConfig = nil

        await loggingService.logInfo(
            component: "BonjourBroadcast",
            message: "Broadcast stopped"
        )
    }

    func updateBridgeStatus(_ status: ServiceBroadcast.BridgeStatus) async throws {
        guard var config = currentConfig else {
            throw BonjourError.notBroadcasting
        }

        await loggingService.logInfo(
            component: "BonjourBroadcast",
            message: "Updating bridge status to \(status.rawValue)"
        )

        // Stop current broadcast
        try await stopBroadcasting()

        // Restart with updated status
        let updatedConfig = ServiceBroadcast(
            deviceName: config.deviceName,
            deviceID: config.deviceID,
            port: config.port,
            bridgeStatus: status,
            certificateHash: config.certificateHash
        )

        try await startBroadcasting(config: updatedConfig)
    }
}

/// Delegate adapter to bridge NetService callbacks to async/await
/// Marked @unchecked Sendable because NetService is non-Sendable but we ensure thread-safety
final class NetServiceDelegateAdapter: NSObject, NetServiceDelegate, @unchecked Sendable {
    var onPublish: ((Bool, String?) -> Void)?

    nonisolated func netServiceDidPublish(_ sender: NetService) {
        Task { @MainActor in
            onPublish?(true, nil)
        }
    }

    nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        let errorMessage = errorDict.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        Task { @MainActor in
            onPublish?(false, errorMessage)
        }
    }
}
