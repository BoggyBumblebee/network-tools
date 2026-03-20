import XCTest
@testable import NetworkTools

final class FormattersTests: XCTestCase {
    func testBitsPerSecondStringFormatting() {
        XCTAssertNil(Formatters.bitsPerSecondString(nil))
        XCTAssertNil(Formatters.bitsPerSecondString(0))
        XCTAssertEqual(Formatters.bitsPerSecondString(100), "100 bps")
        XCTAssertEqual(Formatters.bitsPerSecondString(1_000), "1 Kbps")
        XCTAssertEqual(Formatters.bitsPerSecondString(1_500_000), "1.5 Mbps")
        XCTAssertEqual(Formatters.bitsPerSecondString(1_000_000_000), "1 Gbps")
    }
}
