import Darwin
import Foundation
import IOKit

protocol NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary]
    func snapshot(for interfaceName: String) -> InterfaceSnapshot?
}

final class SystemNetworkInterfaceService: NetworkInterfaceService {
    private var interfaceDetailsCache: [String: (vendor: String?, model: String?)] = [:]

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

        var hardwareAddress: String?
        var ipAddress: String?
        var linkSpeedBitsPerSecond: UInt64?
        var linkStatus: LinkStatus = .unknown
        var stats: InterfaceStatistics?

        for record in records {
            if let macAddress = record.hardwareAddress, hardwareAddress == nil {
                hardwareAddress = macAddress
            }
            if let ipv4 = record.ipv4Address, ipAddress == nil {
                ipAddress = ipv4
            }
            if
                let speed = record.linkSpeedBitsPerSecond,
                speed > (linkSpeedBitsPerSecond ?? 0)
            {
                linkSpeedBitsPerSecond = speed
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

        let speedText = Formatters.bitsPerSecondString(linkSpeedBitsPerSecond)
        let interfaceDetails = vendorAndModel(for: interfaceName)

        return InterfaceSnapshot(
            name: interfaceName,
            hardwareAddress: hardwareAddress,
            ipAddress: ipAddress,
            linkSpeed: speedText,
            transportSpeed: speedText,
            linkStatus: linkStatus,
            vendor: interfaceDetails.vendor,
            model: interfaceDetails.model,
            statistics: fallbackStats
        )
    }

    private struct InterfaceRecord {
        let name: String
        let hardwareType: String?
        let hardwareAddress: String?
        let ipv4Address: String?
        let linkSpeedBitsPerSecond: UInt64?
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
            var hardwareAddress: String?
            if
                let address = interface.pointee.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK)
            {
                let linkAddress = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_dl.self).pointee
                hardwareType = mapHardwareType(linkAddress.sdl_type)
                hardwareAddress = mapHardwareAddress(linkAddress)
            }

            var ipv4Address: String?
            var linkSpeedBitsPerSecond: UInt64?
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
                let speed = UInt64(ifData.ifi_baudrate)
                if speed > 0 {
                    linkSpeedBitsPerSecond = speed
                }
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
                    hardwareAddress: hardwareAddress,
                    ipv4Address: ipv4Address,
                    linkSpeedBitsPerSecond: linkSpeedBitsPerSecond,
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

    private func mapHardwareAddress(_ linkAddress: sockaddr_dl) -> String? {
        let length = Int(linkAddress.sdl_alen)
        guard length > 0 else {
            return nil
        }

        let dataPointer = withUnsafePointer(to: linkAddress.sdl_data) {
            UnsafeRawPointer($0).assumingMemoryBound(to: UInt8.self)
        }

        let macPointer = dataPointer.advanced(by: Int(linkAddress.sdl_nlen))
        let bytes = UnsafeBufferPointer(start: macPointer, count: length)
        return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    private func vendorAndModel(for interfaceName: String) -> (vendor: String?, model: String?) {
        if let cached = interfaceDetailsCache[interfaceName] {
            return cached
        }

        let resolved = resolveVendorAndModel(for: interfaceName)
        interfaceDetailsCache[interfaceName] = resolved
        return resolved
    }

    private func resolveVendorAndModel(for interfaceName: String) -> (vendor: String?, model: String?) {
        guard let matching = IOServiceMatching("IONetworkInterface") else {
            return (nil, nil)
        }
        let matchingDictionary = matching as NSMutableDictionary

        matchingDictionary[kIOPropertyMatchKey] = ["BSD Name": interfaceName]

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator) == KERN_SUCCESS else {
            return (nil, nil)
        }
        defer { IOObjectRelease(iterator) }

        var vendor: String?
        var model: String?
        var service = IOIteratorNext(iterator)

        while service != 0 {
            if model == nil {
                model = firstRegistryString(
                    for: service,
                    keys: ["model", "product-name", "device-model", "IOName"]
                )
                if model == nil, let deviceID = firstRegistryHexID(for: service, keys: ["device-id"]) {
                    model = "0x\(deviceID)"
                }
            }

            if vendor == nil {
                vendor = firstRegistryString(
                    for: service,
                    keys: ["vendor-name", "manufacturer", "vendor", "subsystem-vendor-name"]
                )
                if vendor == nil, let vendorID = firstRegistryHexID(for: service, keys: ["vendor-id"]) {
                    vendor = "0x\(vendorID)"
                }
            }

            let next = IOIteratorNext(iterator)
            IOObjectRelease(service)
            service = next
        }

        return (vendor, model)
    }

    private func firstRegistryString(for service: io_registry_entry_t, keys: [String]) -> String? {
        for key in keys {
            guard let value = registryProperty(for: service, key: key) else {
                continue
            }
            if let string = registryString(from: value) {
                return string
            }
        }
        return nil
    }

    private func firstRegistryHexID(for service: io_registry_entry_t, keys: [String]) -> String? {
        for key in keys {
            guard let value = registryProperty(for: service, key: key) else {
                continue
            }
            if let hexID = registryHexID(from: value) {
                return hexID
            }
        }
        return nil
    }

    private func registryProperty(for service: io_registry_entry_t, key: String) -> AnyObject? {
        let options = IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        return IORegistryEntrySearchCFProperty(
            service,
            kIOServicePlane,
            key as CFString,
            kCFAllocatorDefault,
            options
        )
    }

    private func registryString(from value: AnyObject) -> String? {
        if let text = value as? String {
            return normalized(text)
        }

        if let data = value as? Data {
            if let decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                let trimmedNulls = decoded.replacingOccurrences(of: "\0", with: "")
                return normalized(trimmedNulls)
            }
            return nil
        }

        return nil
    }

    private func registryHexID(from value: AnyObject) -> String? {
        if let number = value as? NSNumber {
            return String(format: "%04x", number.uint64Value & 0xffff)
        }

        if let data = value as? Data, data.count >= 2 {
            var value: UInt32 = 0
            for (index, byte) in data.prefix(4).enumerated() {
                let shift = UInt32(index * 8)
                value |= UInt32(byte) << shift
            }
            return String(format: "%04x", value & 0xffff)
        }

        return nil
    }

    private func normalized(_ text: String) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return cleaned.isEmpty ? nil : cleaned
    }
}
