import Foundation
import OSLog

enum AppLogger {
    static let subsystem = "com.boggybumblebee.NetworkTools"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let info = Logger(subsystem: subsystem, category: "info")
    static let ping = Logger(subsystem: subsystem, category: "ping")
    static let scan = Logger(subsystem: subsystem, category: "scan")
    static let validation = Logger(subsystem: subsystem, category: "validation")
}
