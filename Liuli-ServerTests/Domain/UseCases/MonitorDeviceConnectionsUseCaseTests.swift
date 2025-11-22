import XCTest
@testable import Liuli_Server

@MainActor
final class MonitorDeviceConnectionsUseCaseTests: XCTestCase {
    var sut: MonitorDeviceConnectionsUseCase!
    var mockRepository: MockDeviceMonitorRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockDeviceMonitorRepository()
        sut = MonitorDeviceConnectionsUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Happy Path Tests

    func testExecute_whenRepositoryEmitsDevices_yieldsDevicesFromStream() async throws {
        // Given
        let device1 = DeviceConnection(deviceName: "iPhone 15 Pro", bytesSent: 1024, bytesReceived: 2048)
        let device2 = DeviceConnection(deviceName: "iPad Air", bytesSent: 512, bytesReceived: 1024)
        mockRepository.mockDevices = [device1, device2]

        // When
        let stream = sut.execute()
        var receivedDevices: [DeviceConnection] = []

        for await devices in stream {
            receivedDevices = devices
            break // Get first emission
        }

        // Then
        XCTAssertEqual(receivedDevices.count, 2)
        XCTAssertEqual(receivedDevices[0].deviceName, "iPhone 15 Pro")
        XCTAssertEqual(receivedDevices[0].bytesSent, 1024)
        XCTAssertEqual(receivedDevices[1].deviceName, "iPad Air")
        XCTAssertEqual(receivedDevices[1].bytesReceived, 1024)
    }

    func testExecute_whenNoDevicesConnected_yieldsEmptyArray() async throws {
        // Given
        mockRepository.mockDevices = []

        // When
        let stream = sut.execute()
        var receivedDevices: [DeviceConnection]?

        for await devices in stream {
            receivedDevices = devices
            break
        }

        // Then
        XCTAssertEqual(receivedDevices, [])
    }

    func testExecute_whenDevicesUpdated_yieldsUpdatedList() async throws {
        // Given
        let device = DeviceConnection(deviceName: "iPhone", bytesSent: 100, bytesReceived: 200)
        mockRepository.mockDevices = [device]

        // When
        let stream = sut.execute()
        var emissionCount = 0
        var lastDevices: [DeviceConnection] = []

        for await devices in stream {
            lastDevices = devices
            emissionCount += 1
            if emissionCount == 2 {
                break
            }

            // Simulate adding another device
            if emissionCount == 1 {
                let device2 = DeviceConnection(deviceName: "iPad", bytesSent: 500, bytesReceived: 600)
                mockRepository.mockDevices.append(device2)
                mockRepository.triggerUpdate()
            }
        }

        // Then
        XCTAssertEqual(emissionCount, 2)
        XCTAssertEqual(lastDevices.count, 2)
    }

    // MARK: - Edge Cases

    func testExecute_withSingleDevice_yieldsCorrectly() async throws {
        // Given
        let device = DeviceConnection(
            deviceName: "Test Device",
            status: .active,
            bytesSent: 12345,
            bytesReceived: 67890
        )
        mockRepository.mockDevices = [device]

        // When
        let stream = sut.execute()
        var receivedDevices: [DeviceConnection]?

        for await devices in stream {
            receivedDevices = devices
            break
        }

        // Then
        XCTAssertEqual(receivedDevices?.count, 1)
        XCTAssertEqual(receivedDevices?.first?.deviceName, "Test Device")
        XCTAssertEqual(receivedDevices?.first?.status, .active)
    }

    func testExecute_withDisconnectedDevice_yieldsCorrectStatus() async throws {
        // Given
        let device = DeviceConnection(
            deviceName: "Disconnected Device",
            status: .disconnected,
            bytesSent: 0,
            bytesReceived: 0
        )
        mockRepository.mockDevices = [device]

        // When
        let stream = sut.execute()
        var receivedDevices: [DeviceConnection]?

        for await devices in stream {
            receivedDevices = devices
            break
        }

        // Then
        XCTAssertEqual(receivedDevices?.first?.status, .disconnected)
    }
}

// MARK: - Mock Repository

final class MockDeviceMonitorRepository: DeviceMonitorRepository, @unchecked Sendable {
    var mockDevices: [DeviceConnection] = []
    private var continuation: AsyncStream<[DeviceConnection]>.Continuation?

    nonisolated func observeConnections() -> AsyncStream<[DeviceConnection]> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.mockDevices)
        }
    }

    func addConnection(_ device: DeviceConnection) async {
        mockDevices.append(device)
        continuation?.yield(mockDevices)
    }

    func removeConnection(_ deviceId: UUID) async {
        mockDevices.removeAll { $0.id == deviceId }
        continuation?.yield(mockDevices)
    }

    func updateTrafficStatistics(_ deviceId: UUID, bytesSent: Int64, bytesReceived: Int64) async {
        if let index = mockDevices.firstIndex(where: { $0.id == deviceId }) {
            mockDevices[index] = DeviceConnection(
                id: mockDevices[index].id,
                deviceName: mockDevices[index].deviceName,
                connectedAt: mockDevices[index].connectedAt,
                status: mockDevices[index].status,
                bytesSent: bytesSent,
                bytesReceived: bytesReceived
            )
            continuation?.yield(mockDevices)
        }
    }

    func triggerUpdate() {
        continuation?.yield(mockDevices)
    }
}
