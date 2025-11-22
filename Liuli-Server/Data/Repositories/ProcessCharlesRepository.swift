import Foundation
import AppKit

/// Charles Proxy detection and control using NSWorkspace (FR-036 to FR-040)
public actor ProcessCharlesRepository: CharlesProxyRepository {
    private nonisolated(unsafe) let workspace: NSWorkspace
    private let backoff: ExponentialBackoff

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        self.backoff = ExponentialBackoff(baseDelay: 1.0, maxAttempts: 5)
    }

    public func detectCharles(host: String, port: UInt16) async -> CharlesProxyStatus {
        // Check if Charles process is running
        let isRunning = workspace.runningApplications.contains { app in
            app.bundleIdentifier == "com.xk72.charles" ||
            app.localizedName?.contains("Charles") == true
        }

        guard isRunning else {
            return .unreachable(
                host: host,
                port: port,
                error: "Charles process not running"
            )
        }

        // Try TCP connection to verify Charles is accepting connections
        // TODO: Implement actual TCP connection check with SwiftNIO
        // For now, assume reachable if process is running
        return .reachable(host: host, port: port)
    }

    public func launchCharles() async throws {
        guard let charlesURL = workspace.urlForApplication(withBundleIdentifier: "com.xk72.charles") else {
            throw BridgeServiceError.invalidConfiguration(
                reason: NSLocalizedString("error.charlesNotFound.message", comment: "")
            )
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false // Don't bring to foreground immediately

        try await workspace.openApplication(at: charlesURL, configuration: config)

        Logger.charles.info("Launched Charles Proxy")
    }

    public func isCharlesInstalled() async -> Bool {
        workspace.urlForApplication(withBundleIdentifier: "com.xk72.charles") != nil
    }

    public func getCharlesPath() async -> String? {
        workspace.urlForApplication(withBundleIdentifier: "com.xk72.charles")?.path
    }
}
