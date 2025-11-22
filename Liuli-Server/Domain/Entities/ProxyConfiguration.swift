import Foundation

/// User preferences for bridge service (FR-041 to FR-045)
public struct ProxyConfiguration: Sendable, Codable, Equatable {
    /// SOCKS5 server port (FR-007, default: 9000)
    public var socks5Port: UInt16

    /// Bonjour service name for device discovery (FR-006)
    public var bonjourServiceName: String

    /// Charles Proxy host address (FR-017, FR-040)
    public var charlesHost: String

    /// Charles Proxy port (FR-017, default: 8888)
    public var charlesPort: UInt16

    /// Charles SSL Proxy port (default: 8889)
    public var charlesSSLProxyPort: UInt16

    /// Maximum connection retries (default: 3)
    public var maxRetries: Int

    /// Connection timeout in seconds (default: 30)
    public var connectionTimeout: TimeInterval

    /// Auto-start service on login (FR-045)
    public var autoStartOnLogin: Bool

    /// Auto-launch Charles when service starts (user preference)
    public var autoLaunchCharles: Bool

    /// Show system notifications (FR-029)
    public var notificationsEnabled: Bool

    public nonisolated init(
        socks5Port: UInt16 = 9000,
        bonjourServiceName: String = "Liuli-Server",
        charlesHost: String = "localhost",
        charlesPort: UInt16 = 8888,
        charlesSSLProxyPort: UInt16 = 8889,
        maxRetries: Int = 3,
        connectionTimeout: TimeInterval = 30,
        autoStartOnLogin: Bool = false,
        autoLaunchCharles: Bool = false,
        notificationsEnabled: Bool = true
    ) {
        self.socks5Port = socks5Port
        self.bonjourServiceName = bonjourServiceName
        self.charlesHost = charlesHost
        self.charlesPort = charlesPort
        self.charlesSSLProxyPort = charlesSSLProxyPort
        self.maxRetries = maxRetries
        self.connectionTimeout = connectionTimeout
        self.autoStartOnLogin = autoStartOnLogin
        self.autoLaunchCharles = autoLaunchCharles
        self.notificationsEnabled = notificationsEnabled
    }

    /// Default configuration (FR-043)
    nonisolated public static let `default` = ProxyConfiguration(
        socks5Port: 9000,
        bonjourServiceName: "Liuli-Server",
        charlesHost: "localhost",
        charlesPort: 8888,
        charlesSSLProxyPort: 8889,
        maxRetries: 3,
        connectionTimeout: 30,
        autoStartOnLogin: false,
        autoLaunchCharles: false,
        notificationsEnabled: true
    )

    /// Validate configuration values (FR-044)
    nonisolated public func validate() throws {
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

    // MARK: - Codable (explicit nonisolated implementation)

    enum CodingKeys: String, CodingKey {
        case socks5Port
        case bonjourServiceName
        case charlesHost
        case charlesPort
        case charlesSSLProxyPort
        case maxRetries
        case connectionTimeout
        case autoStartOnLogin
        case autoLaunchCharles
        case notificationsEnabled
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.socks5Port = try container.decode(UInt16.self, forKey: .socks5Port)
        self.bonjourServiceName = try container.decode(String.self, forKey: .bonjourServiceName)
        self.charlesHost = try container.decode(String.self, forKey: .charlesHost)
        self.charlesPort = try container.decode(UInt16.self, forKey: .charlesPort)
        self.charlesSSLProxyPort = try container.decode(UInt16.self, forKey: .charlesSSLProxyPort)
        self.maxRetries = try container.decode(Int.self, forKey: .maxRetries)
        self.connectionTimeout = try container.decode(TimeInterval.self, forKey: .connectionTimeout)
        self.autoStartOnLogin = try container.decode(Bool.self, forKey: .autoStartOnLogin)
        self.autoLaunchCharles = try container.decode(Bool.self, forKey: .autoLaunchCharles)
        self.notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(socks5Port, forKey: .socks5Port)
        try container.encode(bonjourServiceName, forKey: .bonjourServiceName)
        try container.encode(charlesHost, forKey: .charlesHost)
        try container.encode(charlesPort, forKey: .charlesPort)
        try container.encode(charlesSSLProxyPort, forKey: .charlesSSLProxyPort)
        try container.encode(maxRetries, forKey: .maxRetries)
        try container.encode(connectionTimeout, forKey: .connectionTimeout)
        try container.encode(autoStartOnLogin, forKey: .autoStartOnLogin)
        try container.encode(autoLaunchCharles, forKey: .autoLaunchCharles)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
    }
}
