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
}
