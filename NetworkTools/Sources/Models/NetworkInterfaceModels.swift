import Foundation

struct NetworkInterfaceSummary: Identifiable, Equatable {
    var id: String { name }
    let name: String
}

enum LinkStatus: Equatable {
    case up
    case down
    case unknown

    var displayValue: String {
        switch self {
        case .up:
            return "Up"
        case .down:
            return "Down"
        case .unknown:
            return "Unavailable"
        }
    }
}

struct InterfaceStatistics: Equatable {
    let sentPackets: UInt64?
    let sentBytes: UInt64?
    let sendErrors: UInt64?
    let receivedPackets: UInt64?
    let receivedBytes: UInt64?
    let receivedErrors: UInt64?
    let collisions: UInt64?
}

struct InterfaceSnapshot: Equatable {
    let name: String
    let hardwareAddress: String?
    let ipAddress: String?
    let linkSpeed: String?
    let transportSpeed: String?
    let linkStatus: LinkStatus
    let vendor: String?
    let model: String?
    let statistics: InterfaceStatistics
}
