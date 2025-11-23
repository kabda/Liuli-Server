import Foundation
import os.log

/// Protocol for logging critical events for troubleshooting
/// Records: connection establishment, disconnection, authentication failures, errors
public protocol LoggingServiceProtocol: Sendable {
    /// Log connection establishment
    func logConnectionEstablished(
        serverID: UUID,
        deviceID: String,
        devicePlatform: String
    ) async

    /// Log connection disconnection
    func logConnectionDisconnected(
        serverID: UUID,
        deviceID: String,
        reason: String
    ) async

    /// Log authentication failure (certificate validation)
    func logAuthenticationFailed(
        serverID: UUID,
        deviceID: String,
        reason: String
    ) async

    /// Log critical error
    func logError(
        component: String,
        message: String,
        error: Error?
    ) async

    /// Log warning
    func logWarning(
        component: String,
        message: String
    ) async

    /// Log informational message (debug only)
    func logInfo(
        component: String,
        message: String
    ) async
}

// MARK: - Log Event Types

public enum LogEvent: Sendable {
    case connectionEstablished(serverID: UUID, deviceID: String, devicePlatform: String)
    case connectionDisconnected(serverID: UUID, deviceID: String, reason: String)
    case authenticationFailed(serverID: UUID, deviceID: String, reason: String)
    case error(component: String, message: String, error: Error?)
    case warning(component: String, message: String)
    case info(component: String, message: String)
}
