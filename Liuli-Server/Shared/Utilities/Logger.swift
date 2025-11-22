import OSLog

/// OSLog subsystem and category constants for structured logging
enum Logger {
    /// Subsystem identifier for all Liuli-Server logs
    static let subsystem = "com.liuli.server"

    /// Pre-configured OSLog loggers for each category
    nonisolated(unsafe) static let service: OSLog = {
        OSLog(subsystem: subsystem, category: "service")
    }()

    nonisolated(unsafe) static let socks5: OSLog = {
        OSLog(subsystem: subsystem, category: "socks5")
    }()

    nonisolated(unsafe) static let bonjour: OSLog = {
        OSLog(subsystem: subsystem, category: "bonjour")
    }()

    nonisolated(unsafe) static let charles: OSLog = {
        OSLog(subsystem: subsystem, category: "charles")
    }()

    nonisolated(unsafe) static let connections: OSLog = {
        OSLog(subsystem: subsystem, category: "connections")
    }()

    nonisolated(unsafe) static let configuration: OSLog = {
        OSLog(subsystem: subsystem, category: "configuration")
    }()

    nonisolated(unsafe) static let ui: OSLog = {
        OSLog(subsystem: subsystem, category: "ui")
    }()

    nonisolated(unsafe) static let network: OSLog = {
        OSLog(subsystem: subsystem, category: "network")
    }()
}

/// Convenience extension for logging with proper log levels
extension OSLog {
    /// Log an error message (FR-048: .error level)
    nonisolated func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        os_log(.error, log: self, "%{public}@", "\(function):\(line) - \(message)")
    }

    /// Log a warning message (FR-048: .warning level)
    nonisolated func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        os_log(.default, log: self, "⚠️ %{public}@", "\(function):\(line) - \(message)")
    }

    /// Log an info message (FR-048: .info level)
    nonisolated func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        os_log(.info, log: self, "%{public}@", "\(function):\(line) - \(message)")
    }

    /// Log a debug message (FR-048: .debug level, disabled in Release builds)
    nonisolated func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        os_log(.debug, log: self, "🔍 %{public}@", "\(function):\(line) - \(message)")
        #endif
    }
}
