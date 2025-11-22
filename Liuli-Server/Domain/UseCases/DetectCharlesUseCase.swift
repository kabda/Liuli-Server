import Foundation

/// Detect Charles Proxy availability use case (FR-036 to FR-039)
public struct DetectCharlesUseCase: Sendable {
    private let charlesRepository: CharlesProxyRepository

    public init(charlesRepository: CharlesProxyRepository) {
        self.charlesRepository = charlesRepository
    }

    /// Execute Charles detection
    /// - Parameters:
    ///   - host: Charles host address
    ///   - port: Charles port number
    /// - Returns: CharlesProxyStatus
    public func execute(host: String, port: UInt16) async -> CharlesProxyStatus {
        await charlesRepository.detectCharles(host: host, port: port)
    }

    /// Launch Charles Proxy if installed
    public func launchCharles() async throws {
        guard await charlesRepository.isCharlesInstalled() else {
            throw BridgeServiceError.invalidConfiguration(
                reason: "Charles Proxy not found. Please install from www.charlesproxy.com"
            )
        }

        try await charlesRepository.launchCharles()
    }
}
