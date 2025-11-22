import Foundation

/// Exponential backoff retry logic (FR-039: 1s, 2s, 4s, max 5 attempts)
public actor ExponentialBackoff {
    private let baseDelay: TimeInterval
    private let maxAttempts: Int
    private var currentAttempt: Int = 0

    public init(baseDelay: TimeInterval = 1.0, maxAttempts: Int = 5) {
        self.baseDelay = baseDelay
        self.maxAttempts = maxAttempts
    }

    /// Calculate delay for current attempt
    /// - Returns: Delay in seconds (1s, 2s, 4s, 8s, 16s...)
    public func nextDelay() -> TimeInterval? {
        guard currentAttempt < maxAttempts else {
            return nil // Max attempts reached
        }

        let delay = baseDelay * pow(2.0, Double(currentAttempt))
        currentAttempt += 1
        return delay
    }

    /// Reset attempt counter
    public func reset() {
        currentAttempt = 0
    }

    /// Check if should retry
    public var shouldRetry: Bool {
        currentAttempt < maxAttempts
    }

    /// Current attempt number (0-indexed)
    public var attempts: Int {
        currentAttempt
    }
}

/// Convenience function for retry with exponential backoff
public func retryWithBackoff<T>(
    maxAttempts: Int = 5,
    baseDelay: TimeInterval = 1.0,
    operation: @Sendable () async throws -> T
) async throws -> T {
    let backoff = ExponentialBackoff(baseDelay: baseDelay, maxAttempts: maxAttempts)

    while true {
        do {
            return try await operation()
        } catch {
            guard let delay = await backoff.nextDelay() else {
                // Max attempts reached, throw last error
                throw error
            }

            // Wait before retry
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}
