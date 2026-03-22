import XCTest
@testable import NetworkTools

final class ValidationTests: XCTestCase {
    func testValidIPv4AndHostname() {
        XCTAssertTrue(HostValidator.isValidDestination("8.8.8.8"))
        XCTAssertTrue(HostValidator.isValidDestination("example.com"))
        XCTAssertTrue(HostValidator.isValidDestination("xn--d1acpjx3f.xn--p1ai"))
    }

    func testInvalidHostnames() {
        XCTAssertFalse(HostValidator.isValidDestination(""))
        XCTAssertFalse(HostValidator.isValidDestination("   "))
        XCTAssertFalse(HostValidator.isValidDestination("example.com."))
        XCTAssertFalse(HostValidator.isValidDestination("bad_host.example"))
        XCTAssertFalse(HostValidator.isValidDestination("-bad.example"))
    }

    func testPingCountValidationRange() {
        XCTAssertTrue(NumericValidator.isValidPingCount("1"))
        XCTAssertTrue(NumericValidator.isValidPingCount("100"))
        XCTAssertFalse(NumericValidator.isValidPingCount("0"))
        XCTAssertFalse(NumericValidator.isValidPingCount("101"))
        XCTAssertFalse(NumericValidator.isValidPingCount("abc"))
    }

    func testPortRangeValidation() {
        XCTAssertEqual(NumericValidator.parsePortRange(from: "1", to: "1024"), 1...1024)
        XCTAssertEqual(NumericValidator.parsePortRange(from: "80", to: "80"), 80...80)
        XCTAssertNil(NumericValidator.parsePortRange(from: "0", to: "80"))
        XCTAssertNil(NumericValidator.parsePortRange(from: "443", to: "80"))
        XCTAssertNil(NumericValidator.parsePortRange(from: "abc", to: "80"))
    }

    func testPingCompletionReasonTerminationLines() {
        XCTAssertEqual(PingCompletionReason.completedRequestedCount.terminationLine, "--- completed requested count ---")
        XCTAssertEqual(PingCompletionReason.stoppedByUser.terminationLine, "--- stopped by user ---")
        XCTAssertEqual(PingCompletionReason.failedToResolveHost.terminationLine, "--- failed to resolve host ---")
        XCTAssertEqual(
            PingCompletionReason.permissionOrNetworkingError("denied").terminationLine,
            "--- permission or networking error: denied ---"
        )
        XCTAssertEqual(
            PingCompletionReason.timeoutOrOperationalFailure("timeout").terminationLine,
            "--- timeout or operational failure: timeout ---"
        )
    }

    func testPortScanCompletionReasonTerminationLines() {
        XCTAssertEqual(
            PortScanCompletionReason.completed(totalScanned: 42, openPorts: [22, 80, 443]).terminationLine,
            "--- completed: scanned=42 open=3 ---"
        )
        XCTAssertEqual(
            PortScanCompletionReason.stoppedByUser(scanned: 7, openPorts: [53]).terminationLine,
            "--- stopped by user: scanned=7 open=1 ---"
        )
        XCTAssertEqual(PortScanCompletionReason.failedToResolveHost.terminationLine, "--- failed to resolve host ---")
        XCTAssertEqual(
            PortScanCompletionReason.failed("socket closed").terminationLine,
            "--- operational failure: socket closed ---"
        )
    }

    func testDisplayRowIdentityAndEquality() {
        let rowA = DisplayRow(label: "Vendor", value: "Apple")
        let rowB = DisplayRow(label: "Vendor", value: "Apple")

        XCTAssertNotEqual(rowA.id, rowB.id)
        XCTAssertNotEqual(rowA, rowB)
    }

    func testNetworkInterfaceParserParseVendorAndDeviceID() {
        let parsedPCI = NetworkInterfaceParser.parseVendorAndDeviceID(fromIOName: "pci14E4,16B4")
        XCTAssertEqual(parsedPCI.vendorID, "14e4")
        XCTAssertEqual(parsedPCI.deviceID, "16b4")

        let parsedUSB = NetworkInterfaceParser.parseVendorAndDeviceID(fromIOName: "usb05ac,8290")
        XCTAssertEqual(parsedUSB.vendorID, "05ac")
        XCTAssertEqual(parsedUSB.deviceID, "8290")

        XCTAssertNil(NetworkInterfaceParser.parseVendorAndDeviceID(fromIOName: "en0").vendorID)
        XCTAssertNil(NetworkInterfaceParser.parseVendorAndDeviceID(fromIOName: "pci14e4").deviceID)
        XCTAssertNil(NetworkInterfaceParser.parseVendorAndDeviceID(fromIOName: "pciGGGG,1234").vendorID)
    }

    func testNetworkInterfaceParserIsHexString() {
        XCTAssertTrue(NetworkInterfaceParser.isHexString("14e4"))
        XCTAssertTrue(NetworkInterfaceParser.isHexString("05ac"))
        XCTAssertFalse(NetworkInterfaceParser.isHexString(""))
        XCTAssertFalse(NetworkInterfaceParser.isHexString("14E4"))
        XCTAssertFalse(NetworkInterfaceParser.isHexString("1g"))
    }

    func testNetworkInterfaceParserVendorNameAndHostModel() {
        XCTAssertEqual(NetworkInterfaceParser.vendorName(for: "14e4"), "Broadcom")
        XCTAssertEqual(NetworkInterfaceParser.vendorName(for: "8086"), "Intel")
        XCTAssertEqual(NetworkInterfaceParser.vendorName(for: "0bda"), "Realtek")
        XCTAssertNil(NetworkInterfaceParser.vendorName(for: "ffff"))

        XCTAssertTrue(NetworkInterfaceParser.isHostModel("Mac14,2"))
        XCTAssertTrue(NetworkInterfaceParser.isHostModel("MacBookPro18,3"))
        XCTAssertTrue(NetworkInterfaceParser.isHostModel("iMac20,1"))
        XCTAssertTrue(NetworkInterfaceParser.isHostModel("apple silicon"))
        XCTAssertFalse(NetworkInterfaceParser.isHostModel("BCM57765"))
    }

    func testNetworkInterfaceParserRegistryStringAndNormalization() {
        XCTAssertEqual(NetworkInterfaceParser.registryString(from: "  Intel  " as AnyObject), "Intel")

        let utf8Data = Data("Broadcom\0".utf8) as AnyObject
        XCTAssertEqual(NetworkInterfaceParser.registryString(from: utf8Data), "Broadcom")

        let asciiData = Data([0x20, 0x41, 0x53, 0x49, 0x58, 0x20]) as AnyObject
        XCTAssertEqual(NetworkInterfaceParser.registryString(from: asciiData), "ASIX")

        XCTAssertNil(NetworkInterfaceParser.registryString(from: Data([0xff, 0xfe]) as AnyObject))

        XCTAssertEqual(NetworkInterfaceParser.normalized("\n  Apple \t"), "Apple")
        XCTAssertNil(NetworkInterfaceParser.normalized(" \n\t "))
    }

    func testNetworkInterfaceParserRegistryHexIDFromNumberAndData() {
        XCTAssertEqual(NetworkInterfaceParser.registryHexID(from: NSNumber(value: UInt64(0x14e4))), "14e4")
        XCTAssertEqual(NetworkInterfaceParser.registryHexID(from: NSNumber(value: UInt64(0x12345678))), "5678")

        let twoByteData = Data([0xe4, 0x14]) as AnyObject
        XCTAssertEqual(NetworkInterfaceParser.registryHexID(from: twoByteData), "14e4")

        let fourByteData = Data([0xb4, 0x16, 0x00, 0x00]) as AnyObject
        XCTAssertEqual(NetworkInterfaceParser.registryHexID(from: fourByteData), "16b4")

        XCTAssertNil(NetworkInterfaceParser.registryHexID(from: Data([0x01]) as AnyObject))
        XCTAssertNil(NetworkInterfaceParser.registryHexID(from: "not-a-number" as AnyObject))
    }
}
