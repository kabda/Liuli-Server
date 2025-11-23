import Foundation

/// Use case for managing pairing records on server
/// Handles pairing record creation, updates, and purging
public struct ManagePairingRecordsUseCase: Sendable {
    private let pairingRepository: PairingRepositoryProtocol
    private let loggingService: LoggingServiceProtocol

    public init(
        pairingRepository: PairingRepositoryProtocol,
        loggingService: LoggingServiceProtocol
    ) {
        self.pairingRepository = pairingRepository
        self.loggingService = loggingService
    }

    /// Create pairing record on first successful connection
    /// - Parameters:
    ///   - connection: Successful connection to record
    ///   - certificateHash: Server's certificate fingerprint
    /// - Throws: PairingError if save fails
    public func createPairingRecord(
        connection: ServerConnection,
        certificateHash: String
    ) async throws {
        await loggingService.logInfo(
            component: "ManagePairing",
            message: "Creating pairing record for device: \(connection.deviceID)"
        )

        let record = PairingRecord(
            serverID: connection.serverID,
            serverName: "Liuli-Server",  // TODO: Get from config
            deviceID: connection.deviceID,
            devicePlatform: connection.devicePlatform,
            pinnedCertificateHash: certificateHash
        )

        try await pairingRepository.savePairingRecord(record)

        await loggingService.logInfo(
            component: "ManagePairing",
            message: "Pairing record created successfully"
        )
    }

    /// Update pairing record after connection success/failure
    /// - Parameters:
    ///   - serverID: Server identifier
    ///   - success: Whether connection was successful
    /// - Throws: PairingError if update fails
    public func updatePairingRecord(
        serverID: UUID,
        success: Bool
    ) async throws {
        guard var record = try await pairingRepository.getPairingRecord(serverID: serverID) else {
            await loggingService.logWarning(
                component: "ManagePairing",
                message: "Pairing record not found for server: \(serverID.uuidString)"
            )
            return
        }

        // Update record based on connection result
        record = success ? record.recordSuccessfulConnection() : record.recordFailedConnection()

        try await pairingRepository.updatePairingRecord(record)

        await loggingService.logInfo(
            component: "ManagePairing",
            message: "Pairing record updated - success: \(success)"
        )
    }

    /// Get all pairing records
    /// - Returns: Array of pairing records, sorted by last connection
    public func getAllPairingRecords() async throws -> [PairingRecord] {
        try await pairingRepository.getAllPairingRecords()
    }

    /// Delete pairing record (e.g., "Forget Server" action)
    /// - Parameter serverID: Server to forget
    /// - Throws: PairingError if deletion fails
    public func deletePairingRecord(serverID: UUID) async throws {
        await loggingService.logInfo(
            component: "ManagePairing",
            message: "Deleting pairing record for server: \(serverID.uuidString)"
        )

        try await pairingRepository.deletePairingRecord(serverID: serverID)
    }

    /// Purge expired pairing records (30+ days old)
    /// Should be called periodically (e.g., on app launch)
    /// - Returns: Number of records deleted
    public func purgeExpiredRecords() async throws -> Int {
        await loggingService.logInfo(
            component: "ManagePairing",
            message: "Starting automatic purge of expired pairing records"
        )

        let count = try await pairingRepository.purgeExpiredRecords()

        if count > 0 {
            await loggingService.logInfo(
                component: "ManagePairing",
                message: "Purged \(count) expired pairing records"
            )
        }

        return count
    }
}
