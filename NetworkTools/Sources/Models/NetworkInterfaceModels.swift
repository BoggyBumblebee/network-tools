import Foundation

struct NetworkInterfaceSummary: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let hardwareType: String?
    let isActive: Bool

    init(name: String, hardwareType: String? = nil, isActive: Bool = false) {
        self.name = name
        self.hardwareType = hardwareType
        self.isActive = isActive
    }

    var displayName: String {
        guard let hardwareType, !hardwareType.isEmpty else {
            return name
        }
        return "\(hardwareType) (\(name))"
    }
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
    struct Details: Equatable {
        var hardwareAddress: String? = nil
        var ipAddress: String? = nil
        var linkSpeed: String? = nil
        var transportSpeed: String? = nil
        var linkStatus: LinkStatus = .unknown
        var vendor: String? = nil
        var model: String? = nil
        var vendorID: String? = nil
        var deviceID: String? = nil
    }

    let name: String
    let details: Details
    let statistics: InterfaceStatistics

    init(name: String, details: Details = Details(), statistics: InterfaceStatistics) {
        self.name = name
        self.details = details
        self.statistics = statistics
    }

    var hardwareAddress: String? { details.hardwareAddress }
    var ipAddress: String? { details.ipAddress }
    var linkSpeed: String? { details.linkSpeed }
    var transportSpeed: String? { details.transportSpeed }
    var linkStatus: LinkStatus { details.linkStatus }
    var vendor: String? { details.vendor }
    var model: String? { details.model }
    var vendorID: String? { details.vendorID }
    var deviceID: String? { details.deviceID }
}
