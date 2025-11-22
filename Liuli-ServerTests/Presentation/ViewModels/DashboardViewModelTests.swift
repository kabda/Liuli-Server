import XCTest
@testable import Liuli_Server

@MainActor
final class DashboardViewModelTests: XCTestCase {
    var sut: DashboardViewModel!
    var mockDeviceRepository: MockDeviceMonitorRepository!
    var mockNetworkRepository: MockNetworkStatusRepository!
    var mockCharlesRepository: MockCharlesProxyMonitorRepository!

    override func setUp() {
        super.setUp()
        mockDeviceRepository = MockDeviceMonitorRepository()
        mockNetworkRepository = MockNetworkStatusRepository()
        mockCharlesRepository = MockCharlesProxyMonitorRepository()

        let monitorDevicesUseCase = MonitorDeviceConnectionsUseCase(repository: mockDeviceRepository)
        let monitorNetworkUseCase = MonitorNetworkStatusUseCase(repository: mockNetworkRepository)
        let checkCharlesUseCase = CheckCharlesAvailabilityUseCase(
            repository: mockCharlesRepository,
            pollingInterval: 5.0
        )

        sut = DashboardViewModel(
            monitorDevicesUseCase: monitorDevicesUseCase,
            monitorNetworkUseCase: monitorNetworkUseCase,
            checkCharlesUseCase: checkCharlesUseCase
        )
    }

    override func tearDown() {
        sut.stopMonitoring()
        sut = nil
        mockDeviceRepository = nil
        mockNetworkRepository = nil
        mockCharlesRepository = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_hasDefaultState() {
        // Then
        XCTAssertEqual(sut.state.devices, [])
        XCTAssertEqual(sut.state.networkStatus.isListening, false)
        XCTAssertEqual(sut.state.charlesStatus.availability, .unknown)
        XCTAssertFalse(sut.state.isLoading)
        XCTAssertNil(sut.state.selectedDeviceId)
    }

    // MARK: - Device Monitoring Tests

    func testStartMonitoring_updatesDeviceList() async throws {
        // Given
        let device1 = DeviceConnection(deviceName: "iPhone 15 Pro")
        let device2 = DeviceConnection(deviceName: "iPad Air")
        mockDeviceRepository.mockDevices = [device1, device2]

        // When
        sut.startMonitoring()

        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Then
        XCTAssertEqual(sut.state.devices.count, 2)
        XCTAssertEqual(sut.state.devices[0].deviceName, "iPhone 15 Pro")
        XCTAssertEqual(sut.state.devices[1].deviceName, "iPad Air")
    }

    func testStartMonitoring_withNoDevices_showsEmptyList() async throws {
        // Given
        mockDeviceRepository.mockDevices = []

        // When
        sut.startMonitoring()

        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(sut.state.devices, [])
    }

    func testStartMonitoring_whenDeviceAdded_updatesState() async throws {
        // Given
        mockDeviceRepository.mockDevices = []
        sut.startMonitoring()

        // Wait for initial state
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.state.devices.count, 0)

        // When - add device
        let newDevice = DeviceConnection(deviceName: "New iPhone")
        await mockDeviceRepository.addConnection(newDevice)

        // Wait for update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(sut.state.devices.count, 1)
        XCTAssertEqual(sut.state.devices.first?.deviceName, "New iPhone")
    }

    // MARK: - Network Status Monitoring Tests

    func testStartMonitoring_updatesNetworkStatus() async throws {
        // Given
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 3
        )

        // When
        sut.startMonitoring()

        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertTrue(sut.state.networkStatus.isListening)
        XCTAssertEqual(sut.state.networkStatus.listeningPort, 1080)
        XCTAssertEqual(sut.state.networkStatus.activeConnectionCount, 3)
    }

    func testStartMonitoring_whenBridgeDisabled_showsCorrectStatus() async throws {
        // Given
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: false,
            listeningPort: nil,
            activeConnectionCount: 0
        )

        // When
        sut.startMonitoring()

        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertFalse(sut.state.networkStatus.isListening)
        XCTAssertNil(sut.state.networkStatus.listeningPort)
        XCTAssertEqual(sut.state.networkStatus.activeConnectionCount, 0)
    }

    // MARK: - Charles Status Monitoring Tests

    func testStartMonitoring_updatesCharlesStatus() async throws {
        // Given
        mockCharlesRepository.mockStatus = CharlesStatus(
            availability: .available,
            proxyHost: "localhost",
            proxyPort: 8888
        )

        // When
        sut.startMonitoring()

        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(sut.state.charlesStatus.availability, .available)
        XCTAssertEqual(sut.state.charlesStatus.proxyHost, "localhost")
        XCTAssertEqual(sut.state.charlesStatus.proxyPort, 8888)
    }

    func testStartMonitoring_whenCharlesUnavailable_showsCorrectStatus() async throws {
        // Given
        mockCharlesRepository.mockStatus = CharlesStatus(
            availability: .unavailable,
            proxyHost: "localhost",
            proxyPort: 8888,
            errorMessage: "Connection refused"
        )

        // When
        sut.startMonitoring()

        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(sut.state.charlesStatus.availability, .unavailable)
        XCTAssertEqual(sut.state.charlesStatus.errorMessage, "Connection refused")
    }

    // MARK: - Stop Monitoring Tests

    func testStopMonitoring_cancelsAllTasks() async throws {
        // Given
        sut.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        // When
        sut.stopMonitoring()

        // Then - updates should stop (hard to verify without additional state)
        // At minimum, verify no crashes
        XCTAssertNotNil(sut.state)
    }

    func testStopMonitoring_beforeStarting_doesNotCrash() {
        // When/Then
        sut.stopMonitoring()
        XCTAssertNotNil(sut.state)
    }

    // MARK: - Integration Tests

    func testStartMonitoring_updatesAllStatesConcurrently() async throws {
        // Given
        let device = DeviceConnection(deviceName: "Test iPhone")
        mockDeviceRepository.mockDevices = [device]

        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 1
        )

        mockCharlesRepository.mockStatus = CharlesStatus(
            availability: .available,
            proxyHost: "localhost",
            proxyPort: 8888
        )

        // When
        sut.startMonitoring()

        // Wait for all async updates
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        // Then - all states should be updated
        XCTAssertEqual(sut.state.devices.count, 1)
        XCTAssertTrue(sut.state.networkStatus.isListening)
        XCTAssertEqual(sut.state.charlesStatus.availability, .available)
    }

    func testStartAndStopMonitoring_multipleTimes_worksCorrectly() async throws {
        // Given
        mockDeviceRepository.mockDevices = []

        // When - start/stop multiple times
        sut.startMonitoring()
        try await Task.sleep(nanoseconds: 50_000_000)
        sut.stopMonitoring()

        sut.startMonitoring()
        try await Task.sleep(nanoseconds: 50_000_000)
        sut.stopMonitoring()

        // Then
        XCTAssertNotNil(sut.state)
    }

    // MARK: - State Tests

    func testState_isEquatable() {
        // Given
        let fixedDate = Date(timeIntervalSince1970: 1000000)
        let state1 = DashboardState(
            devices: [],
            networkStatus: NetworkStatus(
                isListening: false,
                listeningPort: nil,
                activeConnectionCount: 0,
                lastUpdated: fixedDate
            ),
            charlesStatus: CharlesStatus(
                availability: .unknown,
                proxyHost: "localhost",
                proxyPort: 8888,
                lastChecked: fixedDate
            ),
            isLoading: false,
            selectedDeviceId: nil
        )
        let state2 = DashboardState(
            devices: [],
            networkStatus: NetworkStatus(
                isListening: false,
                listeningPort: nil,
                activeConnectionCount: 0,
                lastUpdated: fixedDate
            ),
            charlesStatus: CharlesStatus(
                availability: .unknown,
                proxyHost: "localhost",
                proxyPort: 8888,
                lastChecked: fixedDate
            ),
            isLoading: false,
            selectedDeviceId: nil
        )

        // Then
        XCTAssertEqual(state1, state2)
    }

    func testState_withDifferentDevices_notEqual() {
        // Given
        let device = DeviceConnection(deviceName: "Test")
        let state1 = DashboardState(devices: [])
        let state2 = DashboardState(devices: [device])

        // Then
        XCTAssertNotEqual(state1, state2)
    }
}
