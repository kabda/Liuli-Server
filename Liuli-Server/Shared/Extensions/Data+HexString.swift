import Foundation

/// Data to hex string conversion for SOCKS5 debug logging
extension Data {
    /// Convert data to hex string for logging
    /// - Parameter separator: Optional separator between bytes (default: space)
    /// - Returns: Hex representation (e.g., "48 65 6c 6c 6f")
    public func hexString(separator: String = " ") -> String {
        return map { String(format: "%02x", $0) }.joined(separator: separator)
    }

    /// Convert data to hex dump with ASCII representation
    /// Useful for detailed protocol debugging
    public func hexDump(bytesPerLine: Int = 16) -> String {
        var result = ""
        let bytes = [UInt8](self)

        for lineStart in stride(from: 0, to: bytes.count, by: bytesPerLine) {
            let lineEnd = min(lineStart + bytesPerLine, bytes.count)
            let lineBytes = bytes[lineStart..<lineEnd]

            // Offset
            result += String(format: "%08x: ", lineStart)

            // Hex bytes
            let hexPart = lineBytes.map { String(format: "%02x", $0) }.joined(separator: " ")
            result += hexPart.padding(toLength: bytesPerLine * 3, withPad: " ", startingAt: 0)

            // ASCII representation
            result += " |"
            for byte in lineBytes {
                let char = (byte >= 32 && byte < 127) ? Character(UnicodeScalar(byte)) : "."
                result.append(char)
            }
            result += "|\n"
        }

        return result
    }
}
