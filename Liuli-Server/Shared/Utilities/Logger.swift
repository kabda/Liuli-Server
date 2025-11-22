import OSLog

/// OSLog subsystem and category constants for structured logging
enum Logger {
    /// Subsystem identifier for all Liuli-Server logs
    static let subsystem = "com.liuli.server"

    /// Log categories for different components
    enum Category {
        /// Bridge service lifecycle and state management
        static let service = "service"

        /// SOCKS5 proxy server and connection handling
        static let socks5 = "socks5"

        /// Bonjour/mDNS service discovery
        static let bonjour = "bonjour"

        /// Charles Proxy detection and integration
        static let charles = "charles"

        /// Connection tracking and statistics
        static let connections = "connections"

        /// Configuration and preferences
        static let configuration = "configuration"

        /// User interface events
        static let ui = "ui"

        /// Network operations and forwarding
        static let network = "network"
    }

    /// Pre-configured OSLog loggers for each category
    static let service = OSLog(subsystem: subsystem, category: Category.service)
    static let socks5 = OSLog(subsystem: subsystem, category: Category.socks5)
    static let bonjour = OSLog(subsystem: subsystem, category: Category.bonjour)
    static let charles = OSLog(subsystem: subsystem, category: Category.charles)
    static let connections = OSLog(subsystem: subsystem, category: Category.connections)
    static let configuration = OSLog(subsystem: subsystem, category: Category.configuration)
    static let ui = OSLog(subsystem: subsystem, category: Category.ui)
    static let network = OSLog(subsystem: subsystem, category: Category.network)
}

/// Convenience extension for logging with proper log levels
extension OSLog {
    /// Log an error message (FR-048: .error level)
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        os_log(.error, log: self, "%{public}@", "\(function):\(line) - \(message)")
    }

    /// Log a warning message (FR-048: .warning level)
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        os_log(.default, log: self, "⚠️ %{public}@", "\(function):\(line) - \(message)")
    }

    /// Log an info message (FR-048: .info level)
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        os_log(.info, log: self, "%{public}@", "\(function):\(line) - \(message)")
    }

    /// Log a debug message (FR-048: .debug level, disabled in Release builds)
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        os_log(.debug, log: self, "🔍 %{public}@", "\(function):\(line) - \(message)")
        #endif
    }
}
