import Foundation

/// Start bridge service use case (FR-001 to FR-050)
public struct StartServiceUseCase: Sendable {
    private let socks5Repository: SOCKS5ServerRepository
    private let bonjourRepository: BonjourServiceRepository
    private let charlesRepository: CharlesProxyRepository
    private let configRepository: ConfigurationRepository

    public init(
        socks5Repository: SOCKS5ServerRepository,
        bonjourRepository: BonjourServiceRepository,
        charlesRepository: CharlesProxyRepository,
        configRepository: ConfigurationRepository
    ) {
        self.socks5Repository = socks5Repository
        self.bonjourRepository = bonjourRepository
        self.charlesRepository = charlesRepository
        self.configRepository = configRepository
    }

    /// Execute service start
    /// - Returns: BridgeService with updated state
    /// - Throws: BridgeServiceError if start fails
    public func execute() async throws -> BridgeService {
        // Load configuration
        let config = try await configRepository.loadConfiguration()
        try config.validate()

        // Check Charles (FR-037: allow start with warning if not reachable)
        let charlesStatus = await charlesRepository.detectCharles(
            host: config.charlesHost,
            port: config.charlesPort
        )

        // Auto-launch Charles if enabled and not running
        if !charlesStatus.isReachable && config.autoLaunchCharles {
            try? await charlesRepository.launchCharles()
        }

        // Start SOCKS5 server (FR-007)
        try await socks5Repository.start(port: config.socks5Port)

        // Start Bonjour advertisement (FR-001)
        let deviceName = ProcessInfo.processInfo.hostName
        try await bonjourRepository.startAdvertising(
            port: config.socks5Port,
            deviceName: deviceName
        )

        return BridgeService(
            state: .running,
            connectedDeviceCount: 0,
            charlesStatus: charlesStatus,
            errorMessage: nil
        )
    }
}
