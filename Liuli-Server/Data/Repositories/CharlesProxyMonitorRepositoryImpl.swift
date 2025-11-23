import Foundation

/// Actor-based repository for Charles proxy availability checking via HTTP CONNECT probe
public actor CharlesProxyMonitorRepositoryImpl: CharlesProxyMonitorRepository {
    private let urlSession: URLSession
    private let settingsRepository: SettingsRepository

    public init(
        urlSession: URLSession = .shared,
        settingsRepository: SettingsRepository
    ) {
        self.urlSession = urlSession
        self.settingsRepository = settingsRepository
    }

    public nonisolated func observeAvailability(interval: TimeInterval) -> AsyncStream<CharlesStatus> {
        AsyncStream { continuation in
            let task = Task(priority: .medium) {
                while !Task.isCancelled {
                    // Load current settings for each check
                    let settings = await self.settingsRepository.loadSettings()
                    let host = settings.charlesProxyHost
                    let port = settings.charlesProxyPort

                    let status = await checkAvailability(host: host, port: port)
                    continuation.yield(status)

                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func checkAvailability(host: String, port: UInt16) async -> CharlesStatus {
        // Perform a lightweight TCP connectivity probe instead of a full HTTP request.
        // If we can connect to host:port within the timeout, we treat Charles as available.
        let timeout: TimeInterval = 2.0

        var inputStream: InputStream?
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: Int(port), inputStream: &inputStream, outputStream: &outputStream)

        guard let input = inputStream, let output = outputStream else {
            let message = "Failed to create TCP streams"
            Logger.charles.error("Charles TCP health check failed: \(message)")
            return CharlesStatus(
                availability: .unavailable,
                proxyHost: host,
                proxyPort: port,
                errorMessage: message
            )
        }

        input.open()
        output.open()

        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            // If either stream reports an error, treat as unavailable.
            if input.streamStatus == .error || output.streamStatus == .error {
                let error = input.streamError ?? output.streamError
                let message = error?.localizedDescription ?? "Stream error"
                Logger.charles.error("Charles TCP health check failed: \(message)")
                input.close()
                output.close()
                return CharlesStatus(
                    availability: .unavailable,
                    proxyHost: host,
                    proxyPort: port,
                    errorMessage: message
                )
            }

            // If streams are open (or at least opening) without error, consider the port reachable.
            if (input.streamStatus == .open || input.streamStatus == .opening) &&
                (output.streamStatus == .open || output.streamStatus == .opening) {
                input.close()
                output.close()
                return CharlesStatus(
                    availability: .available,
                    proxyHost: host,
                    proxyPort: port,
                    errorMessage: nil
                )
            }

            // Poll at a small interval while waiting for the connection to settle.
            try? await Task.sleep(for: .milliseconds(100))
        }

        input.close()
        output.close()

        let message = "TCP probe timed out"
        Logger.charles.error("Charles TCP health check failed: \(message)")
        return CharlesStatus(
            availability: .unavailable,
            proxyHost: host,
            proxyPort: port,
            errorMessage: message
        )
    }
}
