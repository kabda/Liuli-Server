import Foundation

/// Actor-based repository for Charles proxy availability checking via HTTP CONNECT probe
public actor CharlesProxyMonitorRepositoryImpl: CharlesProxyMonitorRepository {
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public nonisolated func observeAvailability(interval: TimeInterval) -> AsyncStream<CharlesStatus> {
        AsyncStream { continuation in
            let task = Task {
                let host = "localhost"
                let port: UInt16 = 8888

                // TODO: Phase 7 - Load from settings
                while !Task.isCancelled {
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
        // Send HTTP CONNECT probe to verify Charles is responding
        let urlString = "http://\(host):\(port)"
        guard let url = URL(string: urlString) else {
            return CharlesStatus(
                availability: .unavailable,
                proxyHost: host,
                proxyPort: port,
                errorMessage: "Invalid URL"
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "CONNECT"
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await urlSession.data(for: request)

            // Check if response indicates proxy is available
            if let httpResponse = response as? HTTPURLResponse {
                let isAvailable = (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 407

                return CharlesStatus(
                    availability: isAvailable ? .available : .unavailable,
                    proxyHost: host,
                    proxyPort: port,
                    errorMessage: isAvailable ? nil : "HTTP \(httpResponse.statusCode)"
                )
            }

            return CharlesStatus(
                availability: .available,
                proxyHost: host,
                proxyPort: port
            )
        } catch {
            return CharlesStatus(
                availability: .unavailable,
                proxyHost: host,
                proxyPort: port,
                errorMessage: error.localizedDescription
            )
        }
    }
}
