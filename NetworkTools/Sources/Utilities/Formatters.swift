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
        return String(value)
    }

    static func bytesOrUnavailable(_ value: UInt64?) -> String {
        guard let value else { return unavailable }
        return byteCountFormatter.string(fromByteCount: Int64(value))
    }
}
