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
    let name: String
    let hardwareAddress: String?
    let ipAddress: String?
    let linkSpeed: String?
    let transportSpeed: String?
    let linkStatus: LinkStatus
    let vendor: String?
    let model: String?
    let vendorID: String?
    let deviceID: String?
    let statistics: InterfaceStatistics

    init(
        name: String,
        hardwareAddress: String?,
        ipAddress: String?,
        linkSpeed: String?,
        transportSpeed: String?,
        linkStatus: LinkStatus,
        vendor: String?,
        model: String?,
        vendorID: String? = nil,
        deviceID: String? = nil,
        statistics: InterfaceStatistics
    ) {
        self.name = name
        self.hardwareAddress = hardwareAddress
        self.ipAddress = ipAddress
        self.linkSpeed = linkSpeed
        self.transportSpeed = transportSpeed
        self.linkStatus = linkStatus
        self.vendor = vendor
        self.model = model
        self.vendorID = vendorID
        self.deviceID = deviceID
        self.statistics = statistics
    }
}
