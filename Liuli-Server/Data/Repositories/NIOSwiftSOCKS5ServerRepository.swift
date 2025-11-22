import Foundation
import NIOCore
import NIOPosix

/// SOCKS5 server repository using SwiftNIO (FR-007 to FR-016)
public actor NIOSwiftSOCKS5ServerRepository: SOCKS5ServerRepository {
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var serverChannel: Channel?
    private var isServerRunning = false
    private var connectionsContinuation: AsyncStream<SOCKS5Connection>.Continuation?
    private var charlesHost: String = "localhost"
    private var charlesPort: Int = 8888
    // Track active connections for traffic updates
    private var activeConnections: [UUID: SOCKS5Connection] = [:]

    public init() {}

    public func start(port: UInt16) async throws {
        guard !isServerRunning else {
            throw BridgeServiceError.serviceStartFailed(reason: "Server already running")
        }

        // Create event loop group with optimal thread count
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.eventLoopGroup = group

        // Capture Charles config for use in non-isolated context
        let charlesHost = self.charlesHost
        let charlesPort = self.charlesPort

        // Create server bootstrap with channel pipeline
        let bootstrap = ServerBootstrap(group: group)
            // Socket options
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Child channel options (for each client connection)
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

            // Child channel initializer (sets up pipeline for each connection)
            .childChannelInitializer { [weak self] channel in
                guard let self = self else {
                    return channel.eventLoop.makeSucceededFuture(())
                }

                return channel.pipeline.addHandlers([
                    // 1. IP address validation (reject non-RFC 1918)
                    IPAddressValidationHandler(),

                    // 2. SOCKS5 protocol handler
                    SOCKS5Handler(
                        charlesHost: charlesHost,
                        charlesPort: charlesPort,
                        onConnectionEstablished: { [weak self] connectionInfo in
                            guard let self = self else { return }

                            Task {
                                await self.notifyConnection(
                                    connectionID: connectionInfo.connectionID,
                                    sourceIP: connectionInfo.sourceIP,
                                    destinationHost: connectionInfo.destinationHost,
                                    destinationPort: connectionInfo.destinationPort
                                )
                            }
                        },
                        onConnectionClosed: { [weak self] sourceIP in
                            guard let self = self else { return }

                            Task {
                                await self.notifyDisconnection(sourceIP: sourceIP)
                            }
                        },
                        onTrafficUpdate: { [weak self] connectionID, bytesUploaded, bytesDownloaded in
                            guard let self = self else { return }

                            Task {
                                await self.updateTraffic(
                                    connectionID: connectionID,
                                    bytesUploaded: bytesUploaded,
                                    bytesDownloaded: bytesDownloaded
                                )
                            }
                        }
                    )
                ])
            }

        do {
            // Bind to port
            let channel = try await bootstrap.bind(host: "0.0.0.0", port: Int(port)).get()
            self.serverChannel = channel
            self.isServerRunning = true

            Logger.socks5.info("SOCKS5 server started on 0.0.0.0:\(port)")

            // Handle server channel closure
            channel.closeFuture.whenComplete { [weak self] _ in
                Task {
                    await self?.handleServerClosed()
                }
            }

        } catch {
            // Cleanup on failure
            try? await group.shutdownGracefully()
            self.eventLoopGroup = nil
            throw BridgeServiceError.serviceStartFailed(reason: "Failed to bind to port \(port): \(error.localizedDescription)")
        }
    }

    public func stop() async throws {
        guard isServerRunning else {
            Logger.socks5.warning("SOCKS5 server not running")
            return
        }

        // Close server channel
        if let channel = serverChannel {
            try await channel.close()
            self.serverChannel = nil
        }

        // Shutdown event loop group
        if let group = eventLoopGroup {
            try await group.shutdownGracefully()
            self.eventLoopGroup = nil
        }

        isServerRunning = false
        connectionsContinuation?.finish()
        connectionsContinuation = nil

        Logger.socks5.info("SOCKS5 server stopped")
    }

    public func isRunning() async -> Bool {
        isServerRunning
    }

    public nonisolated func observeConnections() -> AsyncStream<SOCKS5Connection> {
        AsyncStream { continuation in
            Task {
                await self.setConnectionsContinuation(continuation)
            }
        }
    }

    // MARK: - Private Methods

    private func setConnectionsContinuation(_ continuation: AsyncStream<SOCKS5Connection>.Continuation) {
        self.connectionsContinuation = continuation
    }

    private func notifyConnection(connectionID: UUID, sourceIP: String, destinationHost: String, destinationPort: UInt16) {
        let connection = SOCKS5Connection(
            id: connectionID,
            sourceIP: sourceIP,
            destinationHost: destinationHost,
            destinationPort: destinationPort,
            state: .active,
            startTime: Date()
        )

        activeConnections[connectionID] = connection
        connectionsContinuation?.yield(connection)
        Logger.socks5.info("New SOCKS5 connection: \(sourceIP) -> \(destinationHost):\(destinationPort)")
    }

    private func updateTraffic(connectionID: UUID, bytesUploaded: UInt64, bytesDownloaded: UInt64) {
        guard var connection = activeConnections[connectionID] else { return }

        connection = connection.with(
            bytesUploaded: bytesUploaded,
            bytesDownloaded: bytesDownloaded
        )

        activeConnections[connectionID] = connection
        connectionsContinuation?.yield(connection)
    }

    private func notifyDisconnection(sourceIP: String) {
        // Find connection by source IP
        if let connectionID = activeConnections.first(where: { $0.value.sourceIP == sourceIP })?.key,
           var connection = activeConnections[connectionID] {
            connection = connection.with(state: .closed)
            activeConnections.removeValue(forKey: connectionID)
            connectionsContinuation?.yield(connection)
            Logger.socks5.info("SOCKS5 connection closed: \(sourceIP)")
        }
    }

    private func handleServerClosed() {
        Logger.socks5.warning("Server channel closed unexpectedly")
        isServerRunning = false
        connectionsContinuation?.finish()
        connectionsContinuation = nil
    }

    // MARK: - Configuration

    /// Update Charles proxy target (called before start)
    public func configureCharlesProxy(host: String, port: Int) async {
        self.charlesHost = host
        self.charlesPort = port
        Logger.socks5.debug("Charles proxy configured: \(host):\(port)")
    }
}
