import XCTest
@testable import Liuli_Server

@MainActor
final class ManageSettingsUseCaseTests: XCTestCase {
    var sut: ManageSettingsUseCase!
    var mockRepository: MockSettingsRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockSettingsRepository()
        sut = ManageSettingsUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Load Settings Tests

    func testLoadSettings_returnsDefaultSettings() async throws {
        // Given
        let expectedSettings = ApplicationSettings()
        mockRepository.mockSettings = expectedSettings

        // When
        let settings = await sut.loadSettings()

        // Then
        XCTAssertTrue(mockRepository.loadSettingsCalled)
        XCTAssertEqual(settings.autoStartBridge, expectedSettings.autoStartBridge)
        XCTAssertEqual(settings.charlesProxyHost, expectedSettings.charlesProxyHost)
        XCTAssertEqual(settings.charlesProxyPort, expectedSettings.charlesProxyPort)
        XCTAssertEqual(settings.showMenuBarIcon, expectedSettings.showMenuBarIcon)
        XCTAssertEqual(settings.showMainWindowOnLaunch, expectedSettings.showMainWindowOnLaunch)
    }

    func testLoadSettings_returnsCustomSettings() async throws {
        // Given
        let customSettings = ApplicationSettings(
            autoStartBridge: true,
            charlesProxyHost: "192.168.1.100",
            charlesProxyPort: 9090,
            showMenuBarIcon: false,
            showMainWindowOnLaunch: true
        )
        mockRepository.mockSettings = customSettings

        // When
        let settings = await sut.loadSettings()

        // Then
        XCTAssertEqual(settings.autoStartBridge, true)
        XCTAssertEqual(settings.charlesProxyHost, "192.168.1.100")
        XCTAssertEqual(settings.charlesProxyPort, 9090)
        XCTAssertEqual(settings.showMenuBarIcon, false)
        XCTAssertEqual(settings.showMainWindowOnLaunch, true)
    }

    // MARK: - Save Settings Tests

    func testSaveSettings_whenSuccessful_persistsSettings() async throws {
        // Given
        let newSettings = ApplicationSettings(
            autoStartBridge: true,
            charlesProxyHost: "localhost",
            charlesProxyPort: 8888,
            showMenuBarIcon: true,
            showMainWindowOnLaunch: false
        )

        // When
        try await sut.saveSettings(newSettings)

        // Then
        XCTAssertTrue(mockRepository.saveSettingsCalled)
        XCTAssertEqual(mockRepository.mockSettings.autoStartBridge, true)
        XCTAssertEqual(mockRepository.mockSettings.charlesProxyHost, "localhost")
        XCTAssertEqual(mockRepository.mockSettings.charlesProxyPort, 8888)
    }

    func testSaveSettings_withDifferentProxyHost_savesCorrectly() async throws {
        // Given
        let testCases: [(String, UInt16)] = [
            ("localhost", 8888),
            ("127.0.0.1", 8888),
            ("192.168.1.100", 9090),
            ("10.0.0.1", 3128)
        ]

        for (host, port) in testCases {
            // When
            let settings = ApplicationSettings(
                charlesProxyHost: host,
                charlesProxyPort: port
            )
            try await sut.saveSettings(settings)

            // Then
            XCTAssertEqual(mockRepository.mockSettings.charlesProxyHost, host)
            XCTAssertEqual(mockRepository.mockSettings.charlesProxyPort, port)
        }
    }

    func testSaveSettings_withAutoStartEnabled_savesCorrectly() async throws {
        // Given
        let settings = ApplicationSettings(autoStartBridge: true)

        // When
        try await sut.saveSettings(settings)

        // Then
        XCTAssertTrue(mockRepository.mockSettings.autoStartBridge)
    }

    func testSaveSettings_withAutoStartDisabled_savesCorrectly() async throws {
        // Given
        let settings = ApplicationSettings(autoStartBridge: false)

        // When
        try await sut.saveSettings(settings)

        // Then
        XCTAssertFalse(mockRepository.mockSettings.autoStartBridge)
    }

    func testSaveSettings_withMenuBarIconHidden_savesCorrectly() async throws {
        // Given
        let settings = ApplicationSettings(showMenuBarIcon: false)

        // When
        try await sut.saveSettings(settings)

        // Then
        XCTAssertFalse(mockRepository.mockSettings.showMenuBarIcon)
    }

    func testSaveSettings_withMainWindowOnLaunch_savesCorrectly() async throws {
        // Given
        let settings = ApplicationSettings(showMainWindowOnLaunch: true)

        // When
        try await sut.saveSettings(settings)

        // Then
        XCTAssertTrue(mockRepository.mockSettings.showMainWindowOnLaunch)
    }

    // MARK: - Mark Clean Shutdown Tests

    func testMarkCleanShutdown_callsRepository() async throws {
        // Given/When
        await sut.markCleanShutdown()

        // Then
        XCTAssertTrue(mockRepository.markCleanShutdownCalled)
        XCTAssertTrue(mockRepository.mockCleanShutdown)
    }

    func testMarkCleanShutdown_multipleCallsSucceed() async throws {
        // Given/When
        await sut.markCleanShutdown()
        mockRepository.markCleanShutdownCalled = false

        await sut.markCleanShutdown()

        // Then
        XCTAssertTrue(mockRepository.markCleanShutdownCalled)
    }

    // MARK: - Integration Tests

    func testLoadSaveRoundTrip_preservesSettings() async throws {
        // Given
        let originalSettings = ApplicationSettings(
            autoStartBridge: true,
            charlesProxyHost: "192.168.1.50",
            charlesProxyPort: 7777,
            showMenuBarIcon: false,
            showMainWindowOnLaunch: true
        )

        // When - save
        try await sut.saveSettings(originalSettings)

        // Then - load and verify
        let loadedSettings = await sut.loadSettings()
        XCTAssertEqual(loadedSettings.autoStartBridge, originalSettings.autoStartBridge)
        XCTAssertEqual(loadedSettings.charlesProxyHost, originalSettings.charlesProxyHost)
        XCTAssertEqual(loadedSettings.charlesProxyPort, originalSettings.charlesProxyPort)
        XCTAssertEqual(loadedSettings.showMenuBarIcon, originalSettings.showMenuBarIcon)
        XCTAssertEqual(loadedSettings.showMainWindowOnLaunch, originalSettings.showMainWindowOnLaunch)
    }

    func testMultipleSaves_lastOneWins() async throws {
        // Given
        let settings1 = ApplicationSettings(charlesProxyPort: 8888)
        let settings2 = ApplicationSettings(charlesProxyPort: 9090)
        let settings3 = ApplicationSettings(charlesProxyPort: 7777)

        // When
        try await sut.saveSettings(settings1)
        try await sut.saveSettings(settings2)
        try await sut.saveSettings(settings3)

        // Then
        let finalSettings = await sut.loadSettings()
        XCTAssertEqual(finalSettings.charlesProxyPort, 7777)
    }

    func testSaveAndMarkShutdown_bothSucceed() async throws {
        // Given
        let settings = ApplicationSettings(autoStartBridge: true)

        // When
        try await sut.saveSettings(settings)
        await sut.markCleanShutdown()

        // Then
        XCTAssertTrue(mockRepository.saveSettingsCalled)
        XCTAssertTrue(mockRepository.markCleanShutdownCalled)
        XCTAssertTrue(mockRepository.mockSettings.autoStartBridge)
        XCTAssertTrue(mockRepository.mockCleanShutdown)
    }

    // MARK: - Edge Cases

    func testLoadSettings_afterCleanShutdown_returnsSettings() async throws {
        // Given
        await sut.markCleanShutdown()

        // When
        let settings = await sut.loadSettings()

        // Then
        XCTAssertNotNil(settings)
        XCTAssertTrue(mockRepository.markCleanShutdownCalled)
        XCTAssertTrue(mockRepository.loadSettingsCalled)
    }

    func testSaveSettings_withAllDefaultValues_savesCorrectly() async throws {
        // Given
        let defaultSettings = ApplicationSettings()

        // When
        try await sut.saveSettings(defaultSettings)

        // Then
        let loaded = await sut.loadSettings()
        XCTAssertEqual(loaded.autoStartBridge, false)
        XCTAssertEqual(loaded.charlesProxyHost, "localhost")
        XCTAssertEqual(loaded.charlesProxyPort, 8888)
        XCTAssertEqual(loaded.showMenuBarIcon, true)
        XCTAssertEqual(loaded.showMainWindowOnLaunch, false)
    }
}
