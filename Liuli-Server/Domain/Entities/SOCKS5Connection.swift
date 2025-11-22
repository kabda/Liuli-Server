import Foundation

/// Individual SOCKS5 connection metadata (FR-031)
public struct SOCKS5Connection: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sourceIP: String
    public let destinationHost: String
    public let destinationPort: UInt16
    public let state: ConnectionState
    public let startTime: Date
    public let bytesUploaded: UInt64
    public let bytesDownloaded: UInt64

    public nonisolated init(
        id: UUID = UUID(),
        sourceIP: String,
        destinationHost: String,
        destinationPort: UInt16,
        state: ConnectionState = .connecting,
        startTime: Date,
        bytesUploaded: UInt64 = 0,
        bytesDownloaded: UInt64 = 0
    ) {
        self.id = id
        self.sourceIP = sourceIP
        self.destinationHost = destinationHost
        self.destinationPort = destinationPort
        self.state = state
        self.startTime = startTime
        self.bytesUploaded = bytesUploaded
        self.bytesDownloaded = bytesDownloaded
    }

    /// Connection duration in seconds
    public nonisolated var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    /// Total bytes transferred
    public nonisolated var totalBytes: UInt64 {
        bytesUploaded + bytesDownloaded
    }

    /// Update connection with new byte counts
    public nonisolated func with(
        state: ConnectionState? = nil,
        bytesUploaded: UInt64? = nil,
        bytesDownloaded: UInt64? = nil
    ) -> SOCKS5Connection {
        SOCKS5Connection(
            id: self.id,
            sourceIP: self.sourceIP,
            destinationHost: self.destinationHost,
            destinationPort: self.destinationPort,
            state: state ?? self.state,
            startTime: self.startTime,
            bytesUploaded: bytesUploaded ?? self.bytesUploaded,
            bytesDownloaded: bytesDownloaded ?? self.bytesDownloaded
        )
    }
}
