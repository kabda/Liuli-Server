import Foundation
import NIOCore
import NIOPosix

/// SwiftNIO channel handler for SOCKS5 protocol (RFC 1928)
/// Handles authentication handshake and CONNECT command
nonisolated final class SOCKS5Handler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer

    enum State {
        case waitingForGreeting
        case waitingForRequest
        case forwarding
        case closed
    }

    private var state: State = .waitingForGreeting
    private let charlesHost: String
    private let charlesPort: Int
    private let onConnectionEstablished: @Sendable (SOCKS5ConnectionInfo) -> Void
    private let onConnectionClosed: @Sendable (String) -> Void
    private var hasNotifiedConnection = false  // Track if we've already notified
    private var sourceIP: String?  // Store source IP for disconnection

    struct SOCKS5ConnectionInfo: Sendable {
        let sourceIP: String
        let destinationHost: String
        let destinationPort: UInt16
    }

    init(
        charlesHost: String,
        charlesPort: Int,
        onConnectionEstablished: @escaping @Sendable (SOCKS5ConnectionInfo) -> Void,
        onConnectionClosed: @escaping @Sendable (String) -> Void
    ) {
        self.charlesHost = charlesHost
        self.charlesPort = charlesPort
        self.onConnectionEstablished = onConnectionEstablished
        self.onConnectionClosed = onConnectionClosed
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)

        switch state {
        case .waitingForGreeting:
            handleGreeting(context: context, buffer: &buffer)
        case .waitingForRequest:
            handleRequest(context: context, buffer: &buffer)
        case .forwarding:
            // Data is forwarded by CharlesForwardingHandler
            context.fireChannelRead(data)
        case .closed:
            break
        }
    }

    /// Handle SOCKS5 greeting (RFC 1928 Section 3)
    /// Client sends: [VERSION(1), NMETHODS(1), METHODS(1-255)]
    private func handleGreeting(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        guard buffer.readableBytes >= 2 else {
            Logger.socks5.warning("Incomplete SOCKS5 greeting")
            context.close(promise: nil)
            return
        }

        guard let version = buffer.readInteger(as: UInt8.self),
              version == 0x05 else {
            Logger.socks5.error("Invalid SOCKS version")
            context.close(promise: nil)
            return
        }

        guard let methodCount = buffer.readInteger(as: UInt8.self) else {
            Logger.socks5.error("Missing method count")
            context.close(promise: nil)
            return
        }

        guard buffer.readableBytes >= Int(methodCount) else {
            Logger.socks5.warning("Incomplete method list")
            context.close(promise: nil)
            return
        }

        // Skip methods, we only support NO_AUTH (0x00)
        _ = buffer.readBytes(length: Int(methodCount))

        // Send response: [VERSION(0x05), METHOD(0x00 = NO_AUTH)]
        var response = context.channel.allocator.buffer(capacity: 2)
        response.writeInteger(UInt8(0x05)) // VERSION
        response.writeInteger(UInt8(0x00)) // NO_AUTH

        context.writeAndFlush(wrapInboundOut(response), promise: nil)
        state = .waitingForRequest

        // Notify device connection immediately after successful handshake
        if !hasNotifiedConnection {
            let ip = context.channel.remoteAddress?.ipAddress ?? "unknown"
            self.sourceIP = ip  // Store for disconnection
            let connectionInfo = SOCKS5ConnectionInfo(
                sourceIP: ip,
                destinationHost: "pending",  // Will be updated on CONNECT
                destinationPort: 0
            )
            onConnectionEstablished(connectionInfo)
            hasNotifiedConnection = true
            Logger.socks5.info("New device connected: \(ip)")
        }

        Logger.socks5.debug("SOCKS5 greeting handled, waiting for request")
    }

    /// Handle SOCKS5 request (RFC 1928 Section 4)
    /// Client sends: [VERSION(1), CMD(1), RSV(1), ATYP(1), DST.ADDR(var), DST.PORT(2)]
    private func handleRequest(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        guard buffer.readableBytes >= 4 else {
            Logger.socks5.warning("Incomplete SOCKS5 request")
            return
        }

        guard let version = buffer.readInteger(as: UInt8.self),
              version == 0x05 else {
            sendErrorResponse(context: context, errorCode: 0x01) // General failure
            return
        }

        guard let cmd = buffer.readInteger(as: UInt8.self) else {
            sendErrorResponse(context: context, errorCode: 0x01)
            return
        }

        // Only support CONNECT (0x01)
        guard cmd == 0x01 else {
            Logger.socks5.error("Unsupported SOCKS5 command: \(cmd)")
            // Send error response but keep connection open
            // VPN clients may send multiple requests on the same connection
            sendErrorResponse(context: context, errorCode: 0x07, closeConnection: false)
            return
        }

        _ = buffer.readInteger(as: UInt8.self) // RSV (reserved)

        guard let atyp = buffer.readInteger(as: UInt8.self) else {
            sendErrorResponse(context: context, errorCode: 0x01)
            return
        }

        // Parse destination address
        let destinationHost: String
        switch atyp {
        case 0x01: // IPv4
            guard buffer.readableBytes >= 4,
                  let ipBytes = buffer.readBytes(length: 4) else {
                Logger.socks5.error("Invalid IPv4 address in SOCKS5 request")
                sendErrorResponse(context: context, errorCode: 0x01)
                return
            }
            // Convert IPv4 bytes to string format (e.g., "192.168.1.1")
            destinationHost = "\(ipBytes[0]).\(ipBytes[1]).\(ipBytes[2]).\(ipBytes[3])"

        case 0x03: // Domain name
            // First check if we have at least 1 byte for domain length
            guard buffer.readableBytes >= 1 else {
                Logger.socks5.error("Insufficient data for domain length in SOCKS5 request")
                sendErrorResponse(context: context, errorCode: 0x01)
                return
            }

            // Read domain length
            guard let domainLength = buffer.readInteger(as: UInt8.self),
                  domainLength > 0 else {
                Logger.socks5.error("Invalid domain name length in SOCKS5 request")
                sendErrorResponse(context: context, errorCode: 0x01)
                return
            }

            // Now check if we have enough bytes for the domain string
            guard buffer.readableBytes >= Int(domainLength) else {
                Logger.socks5.error("Insufficient data for domain name in SOCKS5 request (need \(domainLength) bytes, have \(buffer.readableBytes))")
                sendErrorResponse(context: context, errorCode: 0x01)
                return
            }

            guard let domainBytes = buffer.readBytes(length: Int(domainLength)),
                  let domain = String(bytes: domainBytes, encoding: .utf8) else {
                Logger.socks5.error("Failed to decode domain name")
                sendErrorResponse(context: context, errorCode: 0x01)
                return
            }
            destinationHost = domain

        case 0x04: // IPv6
            guard buffer.readableBytes >= 16,
                  let ipv6Bytes = buffer.readBytes(length: 16) else {
                Logger.socks5.error("Invalid IPv6 address in SOCKS5 request")
                sendErrorResponse(context: context, errorCode: 0x01)
                return
            }
            // Format IPv6 address
            var groups: [String] = []
            for i in stride(from: 0, to: 16, by: 2) {
                let high = UInt16(ipv6Bytes[i]) << 8
                let low = UInt16(ipv6Bytes[i + 1])
                groups.append(String(format: "%x", high | low))
            }
            destinationHost = groups.joined(separator: ":")

        default:
            Logger.socks5.error("Unsupported address type: \(atyp)")
            sendErrorResponse(context: context, errorCode: 0x08) // Address type not supported
            return
        }

        guard buffer.readableBytes >= 2,
              let destinationPort = buffer.readInteger(endianness: .big, as: UInt16.self) else {
            Logger.socks5.error("Missing destination port in SOCKS5 request")
            sendErrorResponse(context: context, errorCode: 0x01)
            return
        }

        // Get source IP
        let sourceIP = context.channel.remoteAddress?.ipAddress ?? "unknown"

        Logger.socks5.info("SOCKS5 CONNECT: \(sourceIP) -> \(destinationHost):\(destinationPort)")

        // Notify connection established (if not already notified)
        if !hasNotifiedConnection {
            let connectionInfo = SOCKS5ConnectionInfo(
                sourceIP: sourceIP,
                destinationHost: destinationHost,
                destinationPort: destinationPort
            )
            onConnectionEstablished(connectionInfo)
            hasNotifiedConnection = true
        }

        // Connect to Charles proxy
        connectToCharles(context: context, destinationHost: destinationHost, destinationPort: destinationPort)
    }

    /// Connect to Charles proxy and set up forwarding
    private func connectToCharles(context: ChannelHandlerContext, destinationHost: String, destinationPort: UInt16) {
        let clientChannel = context.channel // Extract to avoid capturing context in closure
        let bootstrap = ClientBootstrap(group: context.eventLoop)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                // Add HTTP CONNECT tunnel handler before forwarding
                channel.pipeline.addHandlers([
                    HTTPCONNECTHandler(
                        targetHost: destinationHost,
                        targetPort: destinationPort,
                        clientChannel: clientChannel
                    )
                ])
            }

        let connectFuture = bootstrap.connect(host: charlesHost, port: charlesPort)

        connectFuture.whenComplete { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let charlesChannel):
                Logger.socks5.info("Connected to Charles proxy at \(self.charlesHost):\(self.charlesPort)")

                // Send success response to client FIRST
                self.sendSuccessResponse(context: context)

                // Add glue handler to forward data between client and Charles
                context.pipeline.addHandler(
                    GlueHandler(peerChannel: charlesChannel),
                    position: .after(self)
                ).whenComplete { _ in
                    self.state = .forwarding
                }

            case .failure(let error):
                Logger.socks5.error("Failed to connect to Charles: \(error)")
                self.sendErrorResponse(context: context, errorCode: 0x05) // Connection refused
            }
        }
    }

    /// Send SOCKS5 success response
    private func sendSuccessResponse(context: ChannelHandlerContext) {
        // Response: [VERSION(0x05), REP(0x00=success), RSV(0x00), ATYP(0x01=IPv4), BND.ADDR(4 bytes), BND.PORT(2 bytes)]
        var response = context.channel.allocator.buffer(capacity: 10)
        response.writeInteger(UInt8(0x05)) // VERSION
        response.writeInteger(UInt8(0x00)) // SUCCESS
        response.writeInteger(UInt8(0x00)) // RSV
        response.writeInteger(UInt8(0x01)) // ATYP = IPv4
        response.writeInteger(UInt32(0), endianness: .big)   // BND.ADDR = 0.0.0.0
        response.writeInteger(UInt16(0), endianness: .big)   // BND.PORT = 0

        context.writeAndFlush(wrapInboundOut(response), promise: nil)
    }

    /// Send SOCKS5 error response
    private func sendErrorResponse(context: ChannelHandlerContext, errorCode: UInt8, closeConnection: Bool = true) {
        var response = context.channel.allocator.buffer(capacity: 10)
        response.writeInteger(UInt8(0x05)) // VERSION
        response.writeInteger(errorCode)   // Error code
        response.writeInteger(UInt8(0x00)) // RSV
        response.writeInteger(UInt8(0x01)) // ATYP = IPv4
        response.writeInteger(UInt32(0), endianness: .big)   // BND.ADDR = 0.0.0.0
        response.writeInteger(UInt16(0), endianness: .big)   // BND.PORT = 0

        if closeConnection {
            context.writeAndFlush(wrapInboundOut(response)).whenComplete { _ in
                context.close(promise: nil)
            }
            state = .closed
        } else {
            context.writeAndFlush(wrapInboundOut(response), promise: nil)
            // Keep connection open, reset to wait for next request
            state = .waitingForRequest
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Logger.socks5.error("SOCKS5 handler error: \(error)")
        context.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        // Connection closed, notify device disconnection
        if let ip = sourceIP {
            onConnectionClosed(ip)
            Logger.socks5.info("Device disconnected: \(ip)")
        }
        context.fireChannelInactive()
    }
}

/// Helper handler to forward data between client and Charles
nonisolated final class GlueHandler: ChannelDuplexHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let peerChannel: Channel

    init(peerChannel: Channel) {
        self.peerChannel = peerChannel
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        peerChannel.writeAndFlush(buffer, promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        peerChannel.close(promise: nil)
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Logger.socks5.error("Glue handler error: \(error)")
        peerChannel.close(promise: nil)
        context.close(promise: nil)
    }
}

/// Handler for forwarding data from Charles back to client
nonisolated final class CharlesForwardingHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private let clientChannel: Channel

    init(clientChannel: Channel) {
        self.clientChannel = clientChannel
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        clientChannel.writeAndFlush(buffer, promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        clientChannel.close(promise: nil)
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Logger.socks5.error("Charles forwarding error: \(error)")
        clientChannel.close(promise: nil)
        context.close(promise: nil)
    }
}

/// Handler to establish HTTP CONNECT tunnel through Charles proxy
nonisolated final class HTTPCONNECTHandler: ChannelInboundHandler, RemovableChannelHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer

    private let targetHost: String
    private let targetPort: UInt16
    private let clientChannel: Channel
    private var connectSent = false
    private var tunnelEstablished = false

    init(targetHost: String, targetPort: UInt16, clientChannel: Channel) {
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.clientChannel = clientChannel
    }

    func channelActive(context: ChannelHandlerContext) {
        // Send HTTP CONNECT request to Charles
        let connectRequest = "CONNECT \(targetHost):\(targetPort) HTTP/1.1\r\nHost: \(targetHost):\(targetPort)\r\n\r\n"
        var buffer = context.channel.allocator.buffer(capacity: connectRequest.utf8.count)
        buffer.writeString(connectRequest)

        context.writeAndFlush(wrapInboundOut(buffer), promise: nil)
        connectSent = true

        Logger.socks5.debug("Sent HTTP CONNECT to Charles for \(targetHost):\(targetPort)")
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)

        if !tunnelEstablished {
            // Parse HTTP response
            guard let responseString = buffer.readString(length: buffer.readableBytes) else {
                Logger.socks5.error("Failed to read CONNECT response")
                context.close(promise: nil)
                return
            }

            Logger.socks5.debug("Charles CONNECT response: \(responseString.prefix(100))")

            // Check for "200 Connection established"
            if responseString.contains("200") {
                tunnelEstablished = true
                Logger.socks5.info("HTTP CONNECT tunnel established through Charles")

                // Remove self from pipeline, now it's just raw data forwarding
                _ = context.pipeline.removeHandler(self)

                // Add bidirectional forwarding handler
                _ = context.pipeline.addHandler(CharlesForwardingHandler(clientChannel: clientChannel))
            } else {
                Logger.socks5.error("Charles rejected CONNECT: \(responseString)")
                clientChannel.close(promise: nil)
                context.close(promise: nil)
            }
        } else {
            // Tunnel established, forward data to client
            clientChannel.writeAndFlush(buffer, promise: nil)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Logger.socks5.error("HTTP CONNECT error: \(error)")
        clientChannel.close(promise: nil)
        context.close(promise: nil)
    }
}

// MARK: - Helper Extensions

extension SocketAddress {
    nonisolated var ipAddress: String? {
        switch self {
        case .v4(let addr):
            var address = addr.address
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &address.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return nil
            }
            // Find null terminator and convert to UTF-8
            if let nullIndex = buffer.firstIndex(of: 0) {
                let utf8 = buffer.prefix(upTo: nullIndex).map { UInt8(bitPattern: $0) }
                return String(decoding: utf8, as: UTF8.self)
            }
            return nil
        case .v6(let addr):
            var address = addr.address
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &address.sin6_addr, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil else {
                return nil
            }
            // Find null terminator and convert to UTF-8
            if let nullIndex = buffer.firstIndex(of: 0) {
                let utf8 = buffer.prefix(upTo: nullIndex).map { UInt8(bitPattern: $0) }
                return String(decoding: utf8, as: UTF8.self)
            }
            return nil
        case .unixDomainSocket:
            return nil
        }
    }
}
