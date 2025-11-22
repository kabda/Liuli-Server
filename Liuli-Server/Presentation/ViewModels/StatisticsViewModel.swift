import Foundation
import Observation

/// Statistics view model (FR-027)
@MainActor
@Observable
public final class StatisticsViewModel {
    private(set) var state: StatisticsViewState

    private let trackStatisticsUseCase: TrackStatisticsUseCase
    private var updateTask: Task<Void, Never>?

    public init(trackStatisticsUseCase: TrackStatisticsUseCase) {
        self.trackStatisticsUseCase = trackStatisticsUseCase
        self.state = StatisticsViewState()
    }

    /// Handle user action
    public func send(_ action: StatisticsViewAction) {
        switch action {
        case .onAppear:
            startObserving()
        case .close:
            stopObserving()
            // Window will be closed by coordinator
        }
    }

    private func startObserving() {
        updateTask = Task {
            for await statistics in trackStatisticsUseCase.observeStatistics() {
                guard !Task.isCancelled else { break }

                state = StatisticsViewState(
                    statistics: statistics,
                    connections: statistics.historicalConnections
                )
            }
        }
    }

    private func stopObserving() {
        updateTask?.cancel()
        updateTask = nil
    }
}
