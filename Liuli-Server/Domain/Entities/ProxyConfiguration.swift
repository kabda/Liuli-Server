import Foundation

/// User preferences for bridge service (FR-041 to FR-045)
public struct ProxyConfiguration: Sendable, Codable, Equatable {
    /// SOCKS5 server port (FR-007, default: 9000)
    public let socks5Port: UInt16

    /// Charles Proxy host address (FR-017, FR-040)
    public let charlesHost: String

    /// Charles Proxy port (FR-017, default: 8888)
    public let charlesPort: UInt16

    /// Auto-start service on login (FR-045)
    public let autoStartOnLogin: Bool

    /// Auto-launch Charles when service starts (user preference)
    public let autoLaunchCharles: Bool

    /// Show system notifications (FR-029)
    public let notificationsEnabled: Bool

    public init(
        socks5Port: UInt16 = 9000,
        charlesHost: String = "localhost",
        charlesPort: UInt16 = 8888,
        autoStartOnLogin: Bool = false,
        autoLaunchCharles: Bool = false,
        notificationsEnabled: Bool = true
    ) {
        self.socks5Port = socks5Port
        self.charlesHost = charlesHost
        self.charlesPort = charlesPort
        self.autoStartOnLogin = autoStartOnLogin
        self.autoLaunchCharles = autoLaunchCharles
        self.notificationsEnabled = notificationsEnabled
    }

    /// Default configuration (FR-043)
    public static let `default` = ProxyConfiguration()

    /// Validate configuration values (FR-044)
    public func validate() throws {
        // Port must be in valid range (1024-65535)
        guard socks5Port >= 1024 && socks5Port <= 65535 else {
            throw BridgeServiceError.invalidConfiguration(reason: "SOCKS5 port must be between 1024 and 65535")
        }

        guard charlesPort >= 1 && charlesPort <= 65535 else {
            throw BridgeServiceError.invalidConfiguration(reason: "Charles port must be between 1 and 65535")
        }

        // Validate host is not empty
        guard !charlesHost.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw BridgeServiceError.invalidConfiguration(reason: "Charles host cannot be empty")
        }
    }
}
