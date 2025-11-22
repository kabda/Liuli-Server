import Foundation

/// SOCKS5 server lifecycle management (FR-007 to FR-016)
public protocol SOCKS5ServerRepository: Sendable {
    /// Configure Charles proxy target (must be called before start)
    func configureCharlesProxy(host: String, port: Int) async

    /// Start SOCKS5 server on specified port
    func start(port: UInt16) async throws

    /// Stop SOCKS5 server
    func stop() async throws

    /// Check if server is running
    func isRunning() async -> Bool

    /// Observe connection events
    func observeConnections() -> AsyncStream<SOCKS5Connection>
}
