import Foundation

/// Dependency injection container for the application
@MainActor
public final class AppDependencyContainer {
    // MARK: - Repositories

    public lazy var configRepository: ConfigurationRepository = {
        UserDefaultsConfigRepository()
    }()

    public lazy var socks5Repository: SOCKS5ServerRepository = {
        NIOSwiftSOCKS5ServerRepository()
    }()

    public lazy var bonjourRepository: BonjourServiceRepository = {
        NetServiceBonjourRepository()
    }()

    public lazy var charlesRepository: CharlesProxyRepository = {
        ProcessCharlesRepository()
    }()

    public lazy var connectionRepository: ConnectionRepository = {
        InMemoryConnectionRepository()
    }()

    // MARK: - Feature 002 Repositories

    public lazy var deviceMonitorRepository: DeviceMonitorRepository = {
        DeviceMonitorRepositoryImpl()
    }()

    public lazy var networkStatusRepository: NetworkStatusRepository = {
        NetworkStatusRepositoryImpl(
            startServiceUseCase: startServiceUseCase,
            stopServiceUseCase: stopServiceUseCase,
            configRepository: configRepository,
            socks5Repository: socks5Repository,
            bridgeService: socks5DeviceBridgeService
        )
    }()

    public lazy var charlesProxyMonitorRepository: CharlesProxyMonitorRepository = {
        let config = URLSessionConfiguration.default
        // Bypass system HTTP proxy settings so that health checks talk directly
        // to the local Charles port instead of going through the proxy again.
        config.connectionProxyDictionary = [:]
        let session = URLSession(configuration: config)
        return CharlesProxyMonitorRepositoryImpl(
            urlSession: session,
            settingsRepository: settingsRepository
        )
    }()

    public lazy var settingsRepository: SettingsRepository = {
        SettingsRepositoryImpl()
    }()

    // MARK: - Services

    public lazy var socks5DeviceBridgeService: SOCKS5DeviceBridgeService = {
        SOCKS5DeviceBridgeService(
            socks5Repository: socks5Repository,
            deviceMonitor: deviceMonitorRepository
        )
    }()

    // MARK: - Use Cases

    public lazy var startServiceUseCase: StartServiceUseCase = {
        StartServiceUseCase(
            socks5Repository: socks5Repository,
            bonjourRepository: bonjourRepository,
            charlesRepository: charlesRepository,
            configRepository: configRepository
        )
    }()

    public lazy var stopServiceUseCase: StopServiceUseCase = {
        StopServiceUseCase(
            socks5Repository: socks5Repository,
            bonjourRepository: bonjourRepository
        )
    }()

    public lazy var detectCharlesUseCase: DetectCharlesUseCase = {
        DetectCharlesUseCase(charlesRepository: charlesRepository)
    }()

    public lazy var trackStatisticsUseCase: TrackStatisticsUseCase = {
        TrackStatisticsUseCase(connectionRepository: connectionRepository)
    }()

    public lazy var manageConfigurationUseCase: ManageConfigurationUseCase = {
        ManageConfigurationUseCase(configRepository: configRepository)
    }()

    public lazy var forwardConnectionUseCase: ForwardConnectionUseCase = {
        ForwardConnectionUseCase(connectionRepository: connectionRepository)
    }()

    // MARK: - Feature 002 Use Cases

    public lazy var monitorDeviceConnectionsUseCase: MonitorDeviceConnectionsUseCase = {
        MonitorDeviceConnectionsUseCase(repository: deviceMonitorRepository)
    }()

    public lazy var monitorNetworkStatusUseCase: MonitorNetworkStatusUseCase = {
        MonitorNetworkStatusUseCase(repository: networkStatusRepository)
    }()

    public lazy var checkCharlesAvailabilityUseCase: CheckCharlesAvailabilityUseCase = {
        CheckCharlesAvailabilityUseCase(repository: charlesProxyMonitorRepository)
    }()

    public lazy var toggleBridgeUseCase: ToggleBridgeUseCase = {
        ToggleBridgeUseCase(
            networkRepository: networkStatusRepository,
            settingsRepository: settingsRepository
        )
    }()

    public lazy var manageSettingsUseCase: ManageSettingsUseCase = {
        ManageSettingsUseCase(repository: settingsRepository)
    }()

    // MARK: - View Models

    public func makeMenuBarViewModel(windowCoordinator: WindowCoordinator) -> MenuBarViewModel {
        MenuBarViewModel(
            toggleBridgeUseCase: toggleBridgeUseCase,
            monitorNetworkUseCase: monitorNetworkStatusUseCase,
            windowCoordinator: windowCoordinator
        )
    }

    public func makeStatisticsViewModel() -> StatisticsViewModel {
        StatisticsViewModel(
            trackStatisticsUseCase: trackStatisticsUseCase
        )
    }

    public func makePreferencesViewModel() -> PreferencesViewModel {
        PreferencesViewModel(
            manageConfigurationUseCase: manageConfigurationUseCase,
            notificationService: NotificationService.shared
        )
    }

    // MARK: - Feature 002 ViewModels

    public func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            monitorDevicesUseCase: monitorDeviceConnectionsUseCase,
            monitorNetworkUseCase: monitorNetworkStatusUseCase,
            checkCharlesUseCase: checkCharlesAvailabilityUseCase
        )
    }

    // MARK: - Window Coordinators

    public func makeDashboardWindowCoordinator() -> DashboardWindowCoordinator {
        DashboardWindowCoordinator(
            viewModel: makeDashboardViewModel()
        )
    }

    public func makeStatisticsWindowCoordinator() -> StatisticsWindowCoordinator {
        StatisticsWindowCoordinator(
            viewModel: makeStatisticsViewModel()
        )
    }

    public func makePreferencesWindowCoordinator() -> PreferencesWindowCoordinator {
        PreferencesWindowCoordinator(
            viewModel: makePreferencesViewModel()
        )
    }

    // Singleton instance
    public static let shared = AppDependencyContainer()

    private init() {}
}
