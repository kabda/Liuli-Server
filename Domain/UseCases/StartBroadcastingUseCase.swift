import Foundation

/// Use case for starting Bonjour broadcast
/// Orchestrates certificate generation and broadcast configuration
public struct StartBroadcastingUseCase: Sendable {
    private let broadcastRepository: BonjourBroadcastRepositoryProtocol
    private let certificateGenerator: CertificateGenerator
    private let loggingService: LoggingServiceProtocol

    public init(
        broadcastRepository: BonjourBroadcastRepositoryProtocol,
        certificateGenerator: CertificateGenerator,
        loggingService: LoggingServiceProtocol
    ) {
        self.broadcastRepository = broadcastRepository
        self.certificateGenerator = certificateGenerator
        self.loggingService = loggingService
    }

    /// Execute broadcast startup
    /// - Parameters:
    ///   - deviceName: User-facing device name
    ///   - deviceID: Server's unique identifier
    ///   - port: SOCKS5 proxy port
    ///   - bridgeStatus: Initial bridge status
    /// - Throws: Error if certificate generation or broadcast fails
    public func execute(
        deviceName: String,
        deviceID: UUID,
        port: Int,
        bridgeStatus: ServiceBroadcast.BridgeStatus
    ) async throws {
        await loggingService.logInfo(
            component: "StartBroadcasting",
            message: "Generating certificate and starting broadcast"
        )

        // Generate or load certificate
        let (_, certificateHash) = try await certificateGenerator.generateSelfSignedCertificate()

        // Create broadcast configuration
        let config = ServiceBroadcast(
            deviceName: deviceName,
            deviceID: deviceID,
            port: port,
            bridgeStatus: bridgeStatus,
            certificateHash: certificateHash
        )

        // Start broadcasting
        try await broadcastRepository.startBroadcasting(config: config)

        await loggingService.logInfo(
            component: "StartBroadcasting",
            message: "Broadcast started successfully with cert hash: \(certificateHash.prefix(16))..."
        )
    }
}
