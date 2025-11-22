import Foundation
import NIOCore

/// SwiftNIO handler to validate client IP addresses against RFC 1918 + link-local ranges
/// Rejects connections from public IP addresses for security (FR-011)
nonisolated final class IPAddressValidationHandler: ChannelInboundHandler, RemovableChannelHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer

    func channelActive(context: ChannelHandlerContext) {
        guard let remoteAddress = context.channel.remoteAddress else {
            Logger.socks5.error("Unable to determine remote address")
            context.close(promise: nil)
            return
        }

        let isValid: Bool
        switch remoteAddress {
        case .v4(let addr):
            let ipString = addr.address.ipAddressString
            isValid = ipString.isLocalNetworkAddress()
            Logger.socks5.debug("Validating IPv4: \(ipString) - valid: \(isValid)")

        case .v6(let addr):
            let ipString = addr.address.ipAddressString
            isValid = ipString.isLocalNetworkAddress()
            Logger.socks5.debug("Validating IPv6: \(ipString) - valid: \(isValid)")

        case .unixDomainSocket:
            // Unix domain sockets are always allowed
            isValid = true
        }

        if !isValid {
            Logger.socks5.warning("Rejected connection from non-local IP: \(remoteAddress)")
            context.close(promise: nil)
            return
        }

        // Remove self from pipeline after validation
        _ = context.pipeline.removeHandler(self)
        context.fireChannelActive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Logger.socks5.error("IP validation error: \(error)")
        context.close(promise: nil)
    }
}

// MARK: - Helper Extensions

extension sockaddr_in {
    nonisolated var ipAddressString: String {
        var address = self.sin_addr
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        _ = inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN))
        // Find null terminator and convert to UTF-8
        if let nullIndex = buffer.firstIndex(of: 0) {
            let utf8 = buffer.prefix(upTo: nullIndex).map { UInt8(bitPattern: $0) }
            return String(decoding: utf8, as: UTF8.self)
        }
        return "0.0.0.0"
    }
}

extension sockaddr_in6 {
    nonisolated var ipAddressString: String {
        var address = self.sin6_addr
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        _ = inet_ntop(AF_INET6, &address, &buffer, socklen_t(INET6_ADDRSTRLEN))
        // Find null terminator and convert to UTF-8
        if let nullIndex = buffer.firstIndex(of: 0) {
            let utf8 = buffer.prefix(upTo: nullIndex).map { UInt8(bitPattern: $0) }
            return String(decoding: utf8, as: UTF8.self)
        }
        return "::"
    }
}
