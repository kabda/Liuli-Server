import XCTest
@testable import Liuli_Server

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    var sut: MenuBarViewModel!
    var mockToggleBridgeUseCase: ToggleBridgeUseCase!
    var mockNetworkRepository: MockNetworkStatusRepository!
    var mockSettingsRepository: MockSettingsRepository!

    override func setUp() {
        super.setUp()
        mockNetworkRepository = MockNetworkStatusRepository()
        mockSettingsRepository = MockSettingsRepository()

        mockToggleBridgeUseCase = ToggleBridgeUseCase(
            networkRepository: mockNetworkRepository,
            settingsRepository: mockSettingsRepository
        )

        let monitorNetworkUseCase = MonitorNetworkStatusUseCase(repository: mockNetworkRepository)

        sut = MenuBarViewModel(
            toggleBridgeUseCase: mockToggleBridgeUseCase,
            monitorNetworkUseCase: monitorNetworkUseCase
        )
    }

    override func tearDown() {
        sut.stopMonitoring()
        sut = nil
        mockToggleBridgeUseCase = nil
        mockNetworkRepository = nil
        mockSettingsRepository = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_hasDefaultState() {
        // Then
        XCTAssertFalse(sut.state.isBridgeEnabled)
        XCTAssertEqual(sut.state.connectionCount, 0)
        XCTAssertFalse(sut.state.networkStatus.isListening)
        XCTAssertNil(sut.state.errorMessage)
    }

    // MARK: - Monitoring Tests

    func testStartMonitoring_updatesBridgeStatus() async throws {
        // Given
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 3
        )

        // When
        sut.startMonitoring()

        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Then
        XCTAssertTrue(sut.state.isBridgeEnabled)
        XCTAssertEqual(sut.state.connectionCount, 3)
        XCTAssertTrue(sut.state.networkStatus.isListening)
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
        XCTAssertFalse(sut.state.isBridgeEnabled)
        XCTAssertEqual(sut.state.connectionCount, 0)
    }

    func testStopMonitoring_cancelsTask() async throws {
        // Given
        sut.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        // When
        sut.stopMonitoring()

        // Then
        XCTAssertNotNil(sut.state)
    }

    // MARK: - Toggle Bridge Action Tests

    func testSendToggleBridge_whenDisabled_enablesBridge() async throws {
        // Given
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: false,
            activeConnectionCount: 0
        )
        sut.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        // When
        sut.send(.toggleBridge)

        // Wait for toggle to complete
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then
        XCTAssertTrue(mockNetworkRepository.enableBridgeCalled)
        XCTAssertNil(sut.state.errorMessage)
    }

    func testSendToggleBridge_whenEnabled_disablesBridge() async throws {
        // Given
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 2
        )
        sut.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        // When
        sut.send(.toggleBridge)

        // Wait for toggle to complete
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then
        XCTAssertTrue(mockNetworkRepository.disableBridgeCalled)
        XCTAssertNil(sut.state.errorMessage)
    }

    func testSendToggleBridge_whenError_setsErrorMessage() async throws {
        // Given
        mockNetworkRepository.shouldThrowError = true
        sut.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        // When
        sut.send(.toggleBridge)

        // Wait for toggle to complete
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then
        XCTAssertNotNil(sut.state.errorMessage)
    }

    // MARK: - Show Main Window Action Tests

    func testSendShowMainWindow_callsCallback() async throws {
        // Given
        var callbackCalled = false
        sut.onShowMainWindow = {
            callbackCalled = true
        }

        // When
        sut.send(.showMainWindow)

        // Wait for action to process
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then
        XCTAssertTrue(callbackCalled)
    }

    func testSendShowMainWindow_withoutCallback_doesNotCrash() async throws {
        // Given
        sut.onShowMainWindow = nil

        // When/Then
        sut.send(.showMainWindow)
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    // MARK: - Open Settings Action Tests

    func testSendOpenSettings_callsCallback() async throws {
        // Given
        var callbackCalled = false
        sut.onOpenSettings = {
            callbackCalled = true
        }

        // When
        sut.send(.openSettings)

        // Wait for action to process
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then
        XCTAssertTrue(callbackCalled)
    }

    func testSendOpenSettings_withoutCallback_doesNotCrash() async throws {
        // Given
        sut.onOpenSettings = nil

        // When/Then
        sut.send(.openSettings)
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    // MARK: - Quit Action Tests

    func testSendQuit_callsCallback() async throws {
        // Given
        var callbackCalled = false
        sut.onQuit = {
            callbackCalled = true
        }

        // When
        sut.send(.quit)

        // Wait for action to process
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then
        XCTAssertTrue(callbackCalled)
    }

    func testSendQuit_withoutCallback_doesNotCrash() async throws {
        // Given
        sut.onQuit = nil

        // When/Then
        sut.send(.quit)
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    // MARK: - Integration Tests

    func testToggleBridgeSequence_enableThenDisable() async throws {
        // Given
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: false,
            activeConnectionCount: 0
        )
        sut.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        // When - enable
        sut.send(.toggleBridge)
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then
        XCTAssertTrue(mockNetworkRepository.enableBridgeCalled)
        mockNetworkRepository.enableBridgeCalled = false

        // When - disable
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 1
        )
        mockNetworkRepository.triggerUpdate()
        try await Task.sleep(nanoseconds: 100_000_000)

        sut.send(.toggleBridge)
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then
        XCTAssertTrue(mockNetworkRepository.disableBridgeCalled)
    }

    func testConnectionCount_updates_whenNetworkStatusChanges() async throws {
        // Given
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 1
        )
        sut.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.state.connectionCount, 1)

        // When - connection count increases
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 5
        )
        mockNetworkRepository.triggerUpdate()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(sut.state.connectionCount, 5)
    }

    // MARK: - State Tests

    func testState_isEquatable() {
        // Given
        let state1 = MenuBarState()
        let state2 = MenuBarState()

        // Then
        XCTAssertEqual(state1, state2)
    }

    func testState_withDifferentEnabled_notEqual() {
        // Given
        let state1 = MenuBarState(isBridgeEnabled: false)
        let state2 = MenuBarState(isBridgeEnabled: true)

        // Then
        XCTAssertNotEqual(state1, state2)
    }

    func testState_withDifferentConnectionCount_notEqual() {
        // Given
        let state1 = MenuBarState(connectionCount: 0)
        let state2 = MenuBarState(connectionCount: 3)

        // Then
        XCTAssertNotEqual(state1, state2)
    }

    func testState_withErrorMessage_notEqual() {
        // Given
        let state1 = MenuBarState(errorMessage: nil)
        let state2 = MenuBarState(errorMessage: "Error")

        // Then
        XCTAssertNotEqual(state1, state2)
    }
}
