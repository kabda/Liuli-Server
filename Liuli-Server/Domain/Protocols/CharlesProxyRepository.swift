import Foundation

/// Charles Proxy detection and control (FR-036 to FR-040)
public protocol CharlesProxyRepository: Sendable {
    /// Detect if Charles Proxy is running and reachable
    func detectCharles(host: String, port: UInt16) async -> CharlesProxyStatus

    /// Launch Charles Proxy application (FR-038)
    func launchCharles() async throws

    /// Check if Charles is installed
    func isCharlesInstalled() async -> Bool

    /// Get Charles installation path
    func getCharlesPath() async -> String?
}
