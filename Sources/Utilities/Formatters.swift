import Foundation

enum Formatters {
    static let unavailable = "Unavailable"

    static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        return formatter
    }()

    static func stringOrUnavailable(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return unavailable }
        return value
    }

    static func numberOrUnavailable(_ value: UInt64?) -> String {
        guard let value else { return unavailable }
        return value.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(0))
        )
    }

    static func bytesOrUnavailable(_ value: UInt64?) -> String {
        guard let value else { return unavailable }
        return byteCountFormatter.string(fromByteCount: Int64(value))
    }

    static func bitsPerSecondString(_ value: UInt64?) -> String? {
        guard let value, value > 0 else { return nil }

        let units = ["bps", "Kbps", "Mbps", "Gbps", "Tbps"]
        var scaled = Double(value)
        var index = 0

        while scaled >= 1000, index < units.count - 1 {
            scaled /= 1000
            index += 1
        }

        let precision: Int
        if scaled >= 100 {
            precision = 0
        } else if scaled >= 10 {
            precision = 1
        } else {
            precision = 2
        }

        var text = String(format: "%.\(precision)f", scaled)
        if text.contains(".") {
            while text.last == "0" {
                text.removeLast()
            }
            if text.last == "." {
                text.removeLast()
            }
        }

        return "\(text) \(units[index])"
    }
}
