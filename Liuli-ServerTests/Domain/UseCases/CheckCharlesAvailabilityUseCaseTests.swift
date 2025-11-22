import XCTest
@testable import Liuli_Server

@MainActor
final class CheckCharlesAvailabilityUseCaseTests: XCTestCase {
    var sut: CheckCharlesAvailabilityUseCase!
    var mockRepository: MockCharlesProxyMonitorRepository!
    let defaultPollingInterval: TimeInterval = 5.0

    override func setUp() {
        super.setUp()
        mockRepository = MockCharlesProxyMonitorRepository()
        sut = CheckCharlesAvailabilityUseCase(
            repository: mockRepository,
            pollingInterval: defaultPollingInterval
        )
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Happy Path Tests

    func testExecute_whenCharlesIsAvailable_yieldsAvailableStatus() async throws {
        // Given
        let expectedStatus = CharlesStatus(
            availability: .available,
            proxyHost: "localhost",
            proxyPort: 8888
        )
        mockRepository.mockStatus = expectedStatus

        // When
        let stream = sut.execute()
        var receivedStatus: CharlesStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.availability, .available)
        XCTAssertEqual(receivedStatus?.proxyHost, "localhost")
        XCTAssertEqual(receivedStatus?.proxyPort, 8888)
        XCTAssertNil(receivedStatus?.errorMessage)
    }

    func testExecute_whenCharlesIsUnavailable_yieldsUnavailableStatus() async throws {
        // Given
        let expectedStatus = CharlesStatus(
            availability: .unavailable,
            proxyHost: "localhost",
            proxyPort: 8888,
            errorMessage: "Connection refused"
        )
        mockRepository.mockStatus = expectedStatus

        // When
        let stream = sut.execute()
        var receivedStatus: CharlesStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.availability, .unavailable)
        XCTAssertEqual(receivedStatus?.errorMessage, "Connection refused")
    }

    func testExecute_whenStatusChanges_yieldsUpdatedStatus() async throws {
        // Given - initially unavailable
        mockRepository.mockStatus = CharlesStatus(
            availability: .unavailable,
            proxyHost: "localhost",
            proxyPort: 8888
        )

        // When
        let stream = sut.execute()
        var emissionCount = 0
        var lastStatus: CharlesStatus?

        for await status in stream {
            lastStatus = status
            emissionCount += 1
            if emissionCount == 2 {
                break
            }

            // Simulate Charles becoming available
            if emissionCount == 1 {
                mockRepository.mockStatus = CharlesStatus(
                    availability: .available,
                    proxyHost: "localhost",
                    proxyPort: 8888
                )
                mockRepository.triggerUpdate()
            }
        }

        // Then
        XCTAssertEqual(emissionCount, 2)
        XCTAssertEqual(lastStatus?.availability, .available)
    }

    // MARK: - Polling Interval Tests

    func testInit_withCustomPollingInterval_usesCustomInterval() {
        // Given
        let customInterval: TimeInterval = 10.0

        // When
        let useCase = CheckCharlesAvailabilityUseCase(
            repository: mockRepository,
            pollingInterval: customInterval
        )

        // Then - verify through execution
        let stream = useCase.execute()
        XCTAssertNotNil(stream)
        XCTAssertEqual(mockRepository.lastObserveInterval, customInterval)
    }

    func testInit_withDefaultPollingInterval_usesDefaultValue() {
        // Given/When
        let useCase = CheckCharlesAvailabilityUseCase(repository: mockRepository)

        // Then
        let stream = useCase.execute()
        XCTAssertNotNil(stream)
        XCTAssertEqual(mockRepository.lastObserveInterval, 5.0)
    }

    // MARK: - CheckOnce Tests

    func testCheckOnce_withAvailableCharles_returnsAvailableStatus() async throws {
        // Given
        let host = "192.168.1.100"
        let port: UInt16 = 9090
        mockRepository.mockStatus = CharlesStatus(
            availability: .available,
            proxyHost: host,
            proxyPort: port
        )

        // When
        let status = await sut.checkOnce(host: host, port: port)

        // Then
        XCTAssertEqual(status.availability, .available)
        XCTAssertEqual(status.proxyHost, host)
        XCTAssertEqual(status.proxyPort, port)
        XCTAssertTrue(mockRepository.checkAvailabilityCalled)
    }

    func testCheckOnce_withUnavailableCharles_returnsUnavailableStatus() async throws {
        // Given
        let host = "localhost"
        let port: UInt16 = 8888
        mockRepository.mockStatus = CharlesStatus(
            availability: .unavailable,
            proxyHost: host,
            proxyPort: port,
            errorMessage: "Timeout"
        )

        // When
        let status = await sut.checkOnce(host: host, port: port)

        // Then
        XCTAssertEqual(status.availability, .unavailable)
        XCTAssertEqual(status.errorMessage, "Timeout")
        XCTAssertTrue(mockRepository.checkAvailabilityCalled)
    }

    // MARK: - Edge Cases

    func testExecute_withUnknownStatus_yieldsUnknownStatus() async throws {
        // Given
        let expectedStatus = CharlesStatus(
            availability: .unknown,
            proxyHost: "localhost",
            proxyPort: 8888
        )
        mockRepository.mockStatus = expectedStatus

        // When
        let stream = sut.execute()
        var receivedStatus: CharlesStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.availability, .unknown)
    }

    func testCheckOnce_withDifferentHosts_usesCorrectParameters() async throws {
        // Given
        let testCases: [(String, UInt16)] = [
            ("localhost", 8888),
            ("127.0.0.1", 8888),
            ("192.168.1.100", 9090),
            ("10.0.0.1", 3128)
        ]

        for (host, port) in testCases {
            // When
            mockRepository.mockStatus = CharlesStatus(
                availability: .available,
                proxyHost: host,
                proxyPort: port
            )
            let status = await sut.checkOnce(host: host, port: port)

            // Then
            XCTAssertEqual(status.proxyHost, host)
            XCTAssertEqual(status.proxyPort, port)
        }
    }

    func testExecute_withTimestamps_yieldsCorrectTimestamps() async throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1234567890)
        let status = CharlesStatus(
            availability: .available,
            proxyHost: "localhost",
            proxyPort: 8888,
            lastChecked: timestamp
        )
        mockRepository.mockStatus = status

        // When
        let stream = sut.execute()
        var receivedStatus: CharlesStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.lastChecked, timestamp)
    }
}

// MARK: - Mock Repository

final class MockCharlesProxyMonitorRepository: CharlesProxyMonitorRepository, @unchecked Sendable {
    var mockStatus: CharlesStatus = CharlesStatus(
        availability: .unknown,
        proxyHost: "localhost",
        proxyPort: 8888
    )
    var checkAvailabilityCalled = false
    var lastObserveInterval: TimeInterval?
    private var continuation: AsyncStream<CharlesStatus>.Continuation?

    nonisolated func observeAvailability(interval: TimeInterval) -> AsyncStream<CharlesStatus> {
        self.lastObserveInterval = interval
        return AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.mockStatus)
        }
    }

    func checkAvailability(host: String, port: UInt16) async -> CharlesStatus {
        checkAvailabilityCalled = true
        return mockStatus
    }

    func triggerUpdate() {
        continuation?.yield(mockStatus)
    }
}
