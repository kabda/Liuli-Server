import Foundation
import os.log

/// Actor implementing structured logging using unified logging framework (os_log)
/// Logs critical events: connection, disconnection, authentication failures, errors
actor LoggingServiceImpl: LoggingServiceProtocol {
    private let logger: Logger
    private let subsystem = "com.liuli.server"

    init() {
        self.logger = Logger(subsystem: subsystem, category: "discovery")
    }

    func logConnectionEstablished(
        serverID: UUID,
        deviceID: String,
        devicePlatform: String
    ) async {
        logger.info("""
            ✅ Connection established
            Server: \(serverID.uuidString)
            Device: \(deviceID) (\(devicePlatform))
            """)
    }

    func logConnectionDisconnected(
        serverID: UUID,
        deviceID: String,
        reason: String
    ) async {
        logger.info("""
            ❌ Connection disconnected
            Server: \(serverID.uuidString)
            Device: \(deviceID)
            Reason: \(reason)
            """)
    }

    func logAuthenticationFailed(
        serverID: UUID,
        deviceID: String,
        reason: String
    ) async {
        logger.error("""
            🔒 Authentication failed
            Server: \(serverID.uuidString)
            Device: \(deviceID)
            Reason: \(reason)
            """)
    }

    func logError(
        component: String,
        message: String,
        error: Error?
    ) async {
        if let error = error {
            logger.error("""
                ⚠️ Error in \(component)
                Message: \(message)
                Error: \(error.localizedDescription)
                """)
        } else {
            logger.error("""
                ⚠️ Error in \(component)
                Message: \(message)
                """)
        }
    }

    func logWarning(
        component: String,
        message: String
    ) async {
        logger.warning("""
            ⚡️ Warning in \(component)
            Message: \(message)
            """)
    }

    func logInfo(
        component: String,
        message: String
    ) async {
        #if DEBUG
        logger.debug("""
            ℹ️ \(component)
            Message: \(message)
            """)
        #endif
    }
}
