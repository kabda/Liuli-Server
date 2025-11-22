import Foundation

/// User preferences and configuration
public struct ApplicationSettings: Sendable, Equatable {
    /// Whether bridge auto-starts on application launch
    public var autoStartBridge: Bool

    /// Charles proxy configuration
    public var charlesProxyHost: String
    public var charlesProxyPort: UInt16

    /// Menu bar icon display preference
    public var showMenuBarIcon: Bool

    /// Main window display preference
    public var showMainWindowOnLaunch: Bool

    public nonisolated init(
        autoStartBridge: Bool = false,
        charlesProxyHost: String = "localhost",
        charlesProxyPort: UInt16 = 8888,
        showMenuBarIcon: Bool = true,
        showMainWindowOnLaunch: Bool = false  // FR-018: menu bar only
    ) {
        self.autoStartBridge = autoStartBridge
        self.charlesProxyHost = charlesProxyHost
        self.charlesProxyPort = charlesProxyPort
        self.showMenuBarIcon = showMenuBarIcon
        self.showMainWindowOnLaunch = showMainWindowOnLaunch
    }
}

// Explicit nonisolated Codable conformance
extension ApplicationSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case autoStartBridge
        case charlesProxyHost
        case charlesProxyPort
        case showMenuBarIcon
        case showMainWindowOnLaunch
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.autoStartBridge = try container.decode(Bool.self, forKey: .autoStartBridge)
        self.charlesProxyHost = try container.decode(String.self, forKey: .charlesProxyHost)
        self.charlesProxyPort = try container.decode(UInt16.self, forKey: .charlesProxyPort)
        self.showMenuBarIcon = try container.decode(Bool.self, forKey: .showMenuBarIcon)
        self.showMainWindowOnLaunch = try container.decode(Bool.self, forKey: .showMainWindowOnLaunch)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(autoStartBridge, forKey: .autoStartBridge)
        try container.encode(charlesProxyHost, forKey: .charlesProxyHost)
        try container.encode(charlesProxyPort, forKey: .charlesProxyPort)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try container.encode(showMainWindowOnLaunch, forKey: .showMainWindowOnLaunch)
    }
}
