import Foundation

/// Forward SOCKS5 connections to Charles Proxy use case (FR-017 to FR-023)
public struct ForwardConnectionUseCase: Sendable {
    private let connectionRepository: ConnectionRepository

    public init(connectionRepository: ConnectionRepository) {
        self.connectionRepository = connectionRepository
    }

    /// Track a new connection
    public func trackConnection(_ connection: SOCKS5Connection) async {
        await connectionRepository.trackConnection(connection)
    }

    /// Update connection byte counts
    public func updateConnection(
        id: UUID,
        bytesUploaded: UInt64,
        bytesDownloaded: UInt64
    ) async {
        await connectionRepository.updateConnection(
            id: id,
            bytesUploaded: bytesUploaded,
            bytesDownloaded: bytesDownloaded
        )
    }

    /// Close connection
    public func closeConnection(id: UUID) async {
        await connectionRepository.removeConnection(id: id)
    }
}
