import XCTest
@testable import Liuli_Server

@MainActor
final class ToggleBridgeUseCaseTests: XCTestCase {
    var sut: ToggleBridgeUseCase!
    var mockNetworkRepository: MockNetworkStatusRepository!
    var mockSettingsRepository: MockSettingsRepository!

    override func setUp() {
        super.setUp()
        mockNetworkRepository = MockNetworkStatusRepository()
        mockSettingsRepository = MockSettingsRepository()
        sut = ToggleBridgeUseCase(
            networkRepository: mockNetworkRepository,
            settingsRepository: mockSettingsRepository
        )
    }

    override func tearDown() {
        sut = nil
        mockNetworkRepository = nil
        mockSettingsRepository = nil
        super.tearDown()
    }

    // MARK: - Enable Bridge Tests

    func testEnable_whenSuccessful_enablesBridgeAndSavesState() async throws {
        // Given
        mockNetworkRepository.shouldThrowError = false
        mockSettingsRepository.mockBridgeState = false

        // When
        try await sut.enable()

        // Then
        XCTAssertTrue(mockNetworkRepository.enableBridgeCalled)
        XCTAssertTrue(mockSettingsRepository.saveBridgeStateCalled)
        XCTAssertEqual(mockSettingsRepository.mockBridgeState, true)
    }

    func testEnable_whenNetworkRepositoryThrowsError_propagatesError() async throws {
        // Given
        mockNetworkRepository.shouldThrowError = true

        // When/Then
        do {
            try await sut.enable()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(mockNetworkRepository.enableBridgeCalled)
            // State should not be saved if enable fails
            XCTAssertFalse(mockSettingsRepository.saveBridgeStateCalled)
        }
    }

    func testEnable_whenAlreadyEnabled_stillExecutes() async throws {
        // Given
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 2
        )
        mockSettingsRepository.mockBridgeState = true

        // When
        try await sut.enable()

        // Then
        XCTAssertTrue(mockNetworkRepository.enableBridgeCalled)
        XCTAssertTrue(mockSettingsRepository.saveBridgeStateCalled)
    }

    // MARK: - Disable Bridge Tests

    func testDisable_whenSuccessful_disablesBridgeAndSavesState() async throws {
        // Given
        mockNetworkRepository.shouldThrowError = false
        mockSettingsRepository.mockBridgeState = true

        // When
        try await sut.disable()

        // Then
        XCTAssertTrue(mockNetworkRepository.disableBridgeCalled)
        XCTAssertTrue(mockSettingsRepository.saveBridgeStateCalled)
        XCTAssertEqual(mockSettingsRepository.mockBridgeState, false)
    }

    func testDisable_whenNetworkRepositoryThrowsError_propagatesError() async throws {
        // Given
        mockNetworkRepository.shouldThrowError = true

        // When/Then
        do {
            try await sut.disable()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(mockNetworkRepository.disableBridgeCalled)
            // State should not be saved if disable fails
            XCTAssertFalse(mockSettingsRepository.saveBridgeStateCalled)
        }
    }

    func testDisable_whenAlreadyDisabled_stillExecutes() async throws {
        // Given
        mockNetworkRepository.mockStatus = NetworkStatus(
            isListening: false,
            activeConnectionCount: 0
        )
        mockSettingsRepository.mockBridgeState = false

        // When
        try await sut.disable()

        // Then
        XCTAssertTrue(mockNetworkRepository.disableBridgeCalled)
        XCTAssertTrue(mockSettingsRepository.saveBridgeStateCalled)
    }

    // MARK: - Get Current State Tests

    func testGetCurrentState_whenEnabled_returnsTrue() async throws {
        // Given
        mockSettingsRepository.mockBridgeState = true

        // When
        let state = await sut.getCurrentState()

        // Then
        XCTAssertTrue(state)
        XCTAssertTrue(mockSettingsRepository.loadBridgeStateCalled)
    }

    func testGetCurrentState_whenDisabled_returnsFalse() async throws {
        // Given
        mockSettingsRepository.mockBridgeState = false

        // When
        let state = await sut.getCurrentState()

        // Then
        XCTAssertFalse(state)
        XCTAssertTrue(mockSettingsRepository.loadBridgeStateCalled)
    }

    // MARK: - Integration Tests

    func testEnableAndDisable_sequence_worksCorrectly() async throws {
        // Given
        mockSettingsRepository.mockBridgeState = false

        // When - enable
        try await sut.enable()
        let stateAfterEnable = await sut.getCurrentState()

        // Then
        XCTAssertTrue(stateAfterEnable)

        // When - disable
        try await sut.disable()
        let stateAfterDisable = await sut.getCurrentState()

        // Then
        XCTAssertFalse(stateAfterDisable)
    }

    func testMultipleEnableCalls_eachCallsRepository() async throws {
        // Given/When
        try await sut.enable()
        mockNetworkRepository.enableBridgeCalled = false

        try await sut.enable()

        // Then
        XCTAssertTrue(mockNetworkRepository.enableBridgeCalled)
    }

    func testMultipleDisableCalls_eachCallsRepository() async throws {
        // Given/When
        try await sut.disable()
        mockNetworkRepository.disableBridgeCalled = false

        try await sut.disable()

        // Then
        XCTAssertTrue(mockNetworkRepository.disableBridgeCalled)
    }
}

// MARK: - Mock Settings Repository

final class MockSettingsRepository: SettingsRepository, @unchecked Sendable {
    var mockSettings = ApplicationSettings()
    var mockBridgeState = false
    var mockCleanShutdown = false

    var loadSettingsCalled = false
    var saveSettingsCalled = false
    var saveBridgeStateCalled = false
    var loadBridgeStateCalled = false
    var markCleanShutdownCalled = false

    func loadSettings() async -> ApplicationSettings {
        loadSettingsCalled = true
        return mockSettings
    }

    func saveSettings(_ settings: ApplicationSettings) async throws {
        saveSettingsCalled = true
        mockSettings = settings
    }

    func saveBridgeState(_ enabled: Bool) async {
        saveBridgeStateCalled = true
        mockBridgeState = enabled
    }

    func loadBridgeState() async -> Bool {
        loadBridgeStateCalled = true
        return mockBridgeState
    }

    func markCleanShutdown() async {
        markCleanShutdownCalled = true
        mockCleanShutdown = true
    }
}
