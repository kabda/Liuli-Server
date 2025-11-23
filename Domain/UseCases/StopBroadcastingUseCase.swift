import Foundation

/// Use case for stopping Bonjour broadcast
/// Cleanly shuts down service announcement
public struct StopBroadcastingUseCase: Sendable {
    private let broadcastRepository: BonjourBroadcastRepositoryProtocol
    private let loggingService: LoggingServiceProtocol

    public init(
        broadcastRepository: BonjourBroadcastRepositoryProtocol,
        loggingService: LoggingServiceProtocol
    ) {
        self.broadcastRepository = broadcastRepository
        self.loggingService = loggingService
    }

    /// Execute broadcast shutdown
    /// - Throws: BonjourError if not currently broadcasting
    public func execute() async throws {
        await loggingService.logInfo(
            component: "StopBroadcasting",
            message: "Stopping broadcast"
        )

        try await broadcastRepository.stopBroadcasting()

        await loggingService.logInfo(
            component: "StopBroadcasting",
            message: "Broadcast stopped successfully"
        )
    }
}
