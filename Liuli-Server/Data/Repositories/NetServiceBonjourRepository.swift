import Foundation

/// Bonjour/mDNS service advertisement using NetService (FR-001 to FR-006)
public actor NetServiceBonjourRepository: NSObject, BonjourServiceRepository, NetServiceDelegate {
    private var netService: NetService?
    private var isCurrentlyAdvertising = false

    public override init() {
        super.init()
    }

    public func startAdvertising(port: UInt16, deviceName: String) async throws {
        guard !isCurrentlyAdvertising else {
            Logger.bonjour.warning("Bonjour already advertising")
            return
        }

        // Create NetService with type _charles-bridge._tcp (FR-001)
        let service = NetService(
            domain: "local.", // FR-001
            type: "_charles-bridge._tcp.",
            name: deviceName, // FR-002: Mac hostname
            port: Int32(port)
        )

        // Set TXT record with version, port, device (FR-003)
        let txtData = NetService.data(fromTXTRecord: [
            "version": "1.0.0".data(using: .utf8)!,
            "port": "\(port)".data(using: .utf8)!,
            "device": deviceName.data(using: .utf8)!
        ])
        service.setTXTRecord(txtData)

        service.delegate = self
        service.publish(options: .listenForConnections)

        self.netService = service
        self.isCurrentlyAdvertising = true

        Logger.bonjour.info("Started Bonjour advertisement: \(deviceName) on port \(port)")
    }

    public func stopAdvertising() async throws {
        guard let service = netService else {
            return
        }

        service.stop()
        service.delegate = nil
        self.netService = nil
        self.isCurrentlyAdvertising = false

        Logger.bonjour.info("Stopped Bonjour advertisement")
    }

    public func isAdvertising() async -> Bool {
        isCurrentlyAdvertising
    }

    // MARK: - NetServiceDelegate

    nonisolated public func netServiceDidPublish(_ sender: NetService) {
        Task {
            await Logger.bonjour.info("Bonjour service published successfully")
        }
    }

    nonisolated public func netService(
        _ sender: NetService,
        didNotPublish errorDict: [String: NSNumber]
    ) {
        Task {
            await Logger.bonjour.error("Bonjour publish failed: \(errorDict)")
        }
    }
}
