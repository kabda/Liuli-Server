import Foundation

/// Extension for ByteCountFormatter with traffic-specific formatting
extension ByteCountFormatter {
    /// Shared formatter for displaying network traffic statistics
    /// Configured to show file-style byte counts (KB, MB, GB) with adaptive precision
    static let trafficFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        formatter.zeroPadsFractionDigits = false
        return formatter
    }()

    /// Format bytes sent/received for display in UI
    /// - Parameter bytes: Number of bytes (Int64)
    /// - Returns: Formatted string (e.g., "1.2 MB", "500 KB")
    static func formatTraffic(_ bytes: Int64) -> String {
        trafficFormatter.string(fromByteCount: bytes)
    }
}
