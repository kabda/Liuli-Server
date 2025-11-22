import XCTest
@testable import Liuli_Server

@MainActor
final class MonitorNetworkStatusUseCaseTests: XCTestCase {
    var sut: MonitorNetworkStatusUseCase!
    var mockRepository: MockNetworkStatusRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockNetworkStatusRepository()
        sut = MonitorNetworkStatusUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Happy Path Tests

    func testExecute_whenBridgeIsListening_yieldsListeningStatus() async throws {
        // Given
        let expectedStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 3
        )
        mockRepository.mockStatus = expectedStatus

        // When
        let stream = sut.execute()
        var receivedStatus: NetworkStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.isListening, true)
        XCTAssertEqual(receivedStatus?.listeningPort, 1080)
        XCTAssertEqual(receivedStatus?.activeConnectionCount, 3)
    }

    func testExecute_whenBridgeIsNotListening_yieldsNotListeningStatus() async throws {
        // Given
        let expectedStatus = NetworkStatus(
            isListening: false,
            listeningPort: nil,
            activeConnectionCount: 0
        )
        mockRepository.mockStatus = expectedStatus

        // When
        let stream = sut.execute()
        var receivedStatus: NetworkStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.isListening, false)
        XCTAssertNil(receivedStatus?.listeningPort)
        XCTAssertEqual(receivedStatus?.activeConnectionCount, 0)
    }

    func testExecute_whenStatusChanges_yieldsUpdatedStatus() async throws {
        // Given - initially not listening
        mockRepository.mockStatus = NetworkStatus(
            isListening: false,
            listeningPort: nil,
            activeConnectionCount: 0
        )

        // When
        let stream = sut.execute()
        var emissionCount = 0
        var lastStatus: NetworkStatus?

        for await status in stream {
            lastStatus = status
            emissionCount += 1
            if emissionCount == 2 {
                break
            }

            // Simulate bridge starting
            if emissionCount == 1 {
                mockRepository.mockStatus = NetworkStatus(
                    isListening: true,
                    listeningPort: 1080,
                    activeConnectionCount: 1
                )
                mockRepository.triggerUpdate()
            }
        }

        // Then
        XCTAssertEqual(emissionCount, 2)
        XCTAssertEqual(lastStatus?.isListening, true)
        XCTAssertEqual(lastStatus?.listeningPort, 1080)
    }

    // MARK: - Connection Count Tests

    func testExecute_withMultipleConnections_yieldsCorrectCount() async throws {
        // Given
        let status = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 10
        )
        mockRepository.mockStatus = status

        // When
        let stream = sut.execute()
        var receivedStatus: NetworkStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.activeConnectionCount, 10)
    }

    func testExecute_withZeroConnections_yieldsZeroCount() async throws {
        // Given
        let status = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 0
        )
        mockRepository.mockStatus = status

        // When
        let stream = sut.execute()
        var receivedStatus: NetworkStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.activeConnectionCount, 0)
    }

    // MARK: - Edge Cases

    func testExecute_withCustomPort_yieldsCorrectPort() async throws {
        // Given
        let status = NetworkStatus(
            isListening: true,
            listeningPort: 9090,
            activeConnectionCount: 2
        )
        mockRepository.mockStatus = status

        // When
        let stream = sut.execute()
        var receivedStatus: NetworkStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.listeningPort, 9090)
    }

    func testExecute_withLastUpdatedTimestamp_yieldsTimestamp() async throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1234567890)
        let status = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: 1,
            lastUpdated: timestamp
        )
        mockRepository.mockStatus = status

        // When
        let stream = sut.execute()
        var receivedStatus: NetworkStatus?

        for await status in stream {
            receivedStatus = status
            break
        }

        // Then
        XCTAssertEqual(receivedStatus?.lastUpdated, timestamp)
    }
}

// MARK: - Mock Repository

final class MockNetworkStatusRepository: NetworkStatusRepository, @unchecked Sendable {
    var mockStatus: NetworkStatus = NetworkStatus(isListening: false, activeConnectionCount: 0)
    var enableBridgeCalled = false
    var disableBridgeCalled = false
    var shouldThrowError = false
    private var continuation: AsyncStream<NetworkStatus>.Continuation?

    nonisolated func observeStatus() -> AsyncStream<NetworkStatus> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.mockStatus)
        }
    }

    func enableBridge() async throws {
        enableBridgeCalled = true
        if shouldThrowError {
            throw MockError.bridgeEnableFailed
        }
        mockStatus = NetworkStatus(
            isListening: true,
            listeningPort: 1080,
            activeConnectionCount: mockStatus.activeConnectionCount
        )
        continuation?.yield(mockStatus)
    }

    func disableBridge() async throws {
        disableBridgeCalled = true
        if shouldThrowError {
            throw MockError.bridgeDisableFailed
        }
        mockStatus = NetworkStatus(
            isListening: false,
            listeningPort: nil,
            activeConnectionCount: mockStatus.activeConnectionCount
        )
        continuation?.yield(mockStatus)
    }

    func triggerUpdate() {
        continuation?.yield(mockStatus)
    }

    enum MockError: Error {
        case bridgeEnableFailed
        case bridgeDisableFailed
    }
}
