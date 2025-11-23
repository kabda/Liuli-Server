import Foundation

/// Protocol for managing pairing records (historical connections)
/// Supports persistent auto-reconnection and reliability tracking
public protocol PairingRepositoryProtocol: Sendable {
    /// Save new pairing record after successful connection
    /// - Parameter record: Pairing record to save
    /// - Throws: PairingError if save fails
    func savePairingRecord(_ record: PairingRecord) async throws

    /// Update existing pairing record (e.g., after connection success/failure)
    /// - Parameter record: Updated pairing record
    /// - Throws: PairingError if update fails
    func updatePairingRecord(_ record: PairingRecord) async throws

    /// Get pairing record for specific server
    /// - Parameter serverID: Server's unique identifier
    /// - Returns: Pairing record if exists, nil otherwise
    func getPairingRecord(serverID: UUID) async throws -> PairingRecord?

    /// Get all pairing records, sorted by last connection time (most recent first)
    /// - Returns: Array of pairing records
    func getAllPairingRecords() async throws -> [PairingRecord]

    /// Get last connected server for auto-reconnection
    /// - Returns: Most recently connected pairing record, or nil if none
    func getLastConnectedServer() async throws -> PairingRecord?

    /// Delete pairing record (e.g., "Forget Server" action)
    /// - Parameter serverID: Server to forget
    /// - Throws: PairingError if deletion fails
    func deletePairingRecord(serverID: UUID) async throws

    /// Delete all expired pairing records (older than 30 days)
    /// - Returns: Number of records deleted
    func purgeExpiredRecords() async throws -> Int
}

// MARK: - Errors

public enum PairingError: Error, LocalizedError {
    case saveFailed(reason: String)
    case updateFailed(reason: String)
    case deleteFailed(reason: String)
    case notFound

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let reason):
            return "Failed to save pairing record: \(reason)"
        case .updateFailed(let reason):
            return "Failed to update pairing record: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete pairing record: \(reason)"
        case .notFound:
            return "Pairing record not found"
        }
    }
}
