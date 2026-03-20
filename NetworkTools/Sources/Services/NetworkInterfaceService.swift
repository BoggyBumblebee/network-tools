import Darwin
import Foundation

protocol NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary]
    func snapshot(for interfaceName: String) -> InterfaceSnapshot?
}

final class SystemNetworkInterfaceService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        var names = Set<String>()
        var hardwareTypeByName: [String: String] = [:]
        var isActiveByName: [String: Bool] = [:]

        for record in readInterfaceRecords() {
            names.insert(record.name)
            if hardwareTypeByName[record.name] == nil, let hardwareType = record.hardwareType {
                hardwareTypeByName[record.name] = hardwareType
            }
            isActiveByName[record.name] = (isActiveByName[record.name] ?? false) || record.isActive
        }

        return names
            .sorted()
            .compactMap { name in
                guard isActiveByName[name] == true else {
                    return nil
                }
                return NetworkInterfaceSummary(name: name, hardwareType: hardwareTypeByName[name])
            }
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        let records = readInterfaceRecords().filter { $0.name == interfaceName }
        guard !records.isEmpty else { return nil }

        var ipAddress: String?
        var linkStatus: LinkStatus = .unknown
        var stats: InterfaceStatistics?

        for record in records {
            if let ipv4 = record.ipv4Address, ipAddress == nil {
                ipAddress = ipv4
            }
            if record.isUp != nil {
                linkStatus = record.isUp == true ? .up : .down
            }
            if let recordStats = record.statistics {
                stats = recordStats
            }
        }

        let fallbackStats = stats ?? InterfaceStatistics(
            sentPackets: nil,
            sentBytes: nil,
            sendErrors: nil,
            receivedPackets: nil,
            receivedBytes: nil,
            receivedErrors: nil,
            collisions: nil
        )

        return InterfaceSnapshot(
            name: interfaceName,
            hardwareAddress: nil,
            ipAddress: ipAddress,
            linkSpeed: nil,
            transportSpeed: nil,
            linkStatus: linkStatus,
            vendor: nil,
            model: nil,
            statistics: fallbackStats
        )
    }

    private struct InterfaceRecord {
        let name: String
        let hardwareType: String?
        let ipv4Address: String?
        let isUp: Bool?
        let isActive: Bool
        let statistics: InterfaceStatistics?
    }

    private func readInterfaceRecords() -> [InterfaceRecord] {
        var addressesPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressesPointer) == 0, let first = addressesPointer else {
            AppLogger.info.error("Interface enumeration failed")
            return []
        }

        defer { freeifaddrs(first) }

        var records: [InterfaceRecord] = []
        var current: UnsafeMutablePointer<ifaddrs>? = first

        while let interface = current {
            let name = String(cString: interface.pointee.ifa_name)
            let flags = Int32(interface.pointee.ifa_flags)
            let isUp = (flags & Int32(IFF_UP)) != 0
            let isRunning = (flags & Int32(IFF_RUNNING)) != 0
            let isActive = isUp && isRunning

            var hardwareType: String?
            if
                let address = interface.pointee.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK)
            {
                let linkAddress = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_dl.self).pointee
                hardwareType = mapHardwareType(linkAddress.sdl_type)
            }

            var ipv4Address: String?
            if let addr = interface.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    addr,
                    socklen_t(addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    ipv4Address = String(cString: hostname)
                }
            }

            var stats: InterfaceStatistics?
            if let data = interface.pointee.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                stats = InterfaceStatistics(
                    sentPackets: UInt64(ifData.ifi_opackets),
                    sentBytes: UInt64(ifData.ifi_obytes),
                    sendErrors: UInt64(ifData.ifi_oerrors),
                    receivedPackets: UInt64(ifData.ifi_ipackets),
                    receivedBytes: UInt64(ifData.ifi_ibytes),
                    receivedErrors: UInt64(ifData.ifi_ierrors),
                    collisions: UInt64(ifData.ifi_collisions)
                )
            }

            records.append(
                InterfaceRecord(
                    name: name,
                    hardwareType: hardwareType,
                    ipv4Address: ipv4Address,
                    isUp: isUp,
                    isActive: isActive,
                    statistics: stats
                )
            )
            current = interface.pointee.ifa_next
        }

        return records
    }

    private func mapHardwareType(_ type: UInt8) -> String? {
        switch Int32(type) {
        case IFT_ETHER:
            return "Ethernet"
        case IFT_LOOP:
            return "Loopback"
        default:
            return nil
        }
    }
}
