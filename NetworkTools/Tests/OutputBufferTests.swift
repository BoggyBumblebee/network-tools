import XCTest
@testable import NetworkTools

final class OutputBufferTests: XCTestCase {
    func testOutputBufferTruncatesByLineLimit() {
        var buffer = OutputBuffer()
        for index in 0...(OutputBuffer.maxLines + 5) {
            buffer.append("line-\(index)")
        }

        XCTAssertTrue(buffer.didTruncate)
        XCTAssertLessThanOrEqual(buffer.lines.count, OutputBuffer.maxLines)
        XCTAssertTrue(buffer.renderedText.contains("[output truncated: oldest lines removed]"))
    }
}
