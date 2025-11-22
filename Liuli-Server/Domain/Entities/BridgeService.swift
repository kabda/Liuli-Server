import Foundation

/// Bridge service state and lifecycle coordination (FR-001 to FR-050)
public struct BridgeService: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let state: ServiceState
    public let connectedDeviceCount: Int
    public let charlesStatus: CharlesProxyStatus
    public let lastStateChange: Date
    public let errorMessage: String?

    public init(
        id: UUID = UUID(),
        state: ServiceState = .idle,
        connectedDeviceCount: Int = 0,
        charlesStatus: CharlesProxyStatus = .unknown,
        lastStateChange: Date = Date(),
        errorMessage: String? = nil
    ) {
        self.id = id
        self.state = state
        self.connectedDeviceCount = connectedDeviceCount
        self.charlesStatus = charlesStatus
        self.lastStateChange = lastStateChange
        self.errorMessage = errorMessage
    }

    /// Create a new instance with updated state
    public func with(
        state: ServiceState? = nil,
        connectedDeviceCount: Int? = nil,
        charlesStatus: CharlesProxyStatus? = nil,
        errorMessage: String? = nil
    ) -> BridgeService {
        BridgeService(
            id: self.id,
            state: state ?? self.state,
            connectedDeviceCount: connectedDeviceCount ?? self.connectedDeviceCount,
            charlesStatus: charlesStatus ?? self.charlesStatus,
            lastStateChange: Date(),
            errorMessage: errorMessage ?? self.errorMessage
        )
    }
}
