import XCTest
@testable import NetworkTools

final class RootTabViewTests: XCTestCase {
    func testInitialTabDefaultsToInfoWhenNoArgumentOrUnknownValue() {
        XCTAssertEqual(RootTabView.initialTab(launchArguments: []), .info)
        XCTAssertEqual(
            RootTabView.initialTab(launchArguments: ["--uitesting-select-tab=unknown"]),
            .info
        )
    }

    func testInitialTabResolvesSupportedUITestArguments() {
        XCTAssertEqual(
            RootTabView.initialTab(launchArguments: ["--uitesting-select-tab=info"]),
            .info
        )
        XCTAssertEqual(
            RootTabView.initialTab(launchArguments: ["--uitesting-select-tab=ping"]),
            .ping
        )
        XCTAssertEqual(
            RootTabView.initialTab(launchArguments: ["--uitesting-select-tab=portscan"]),
            .portScan
        )
        XCTAssertEqual(
            RootTabView.initialTab(launchArguments: ["--uitesting-select-tab=port-scan"]),
            .portScan
        )
        XCTAssertEqual(
            RootTabView.initialTab(launchArguments: ["--uitesting-select-tab=port_scan"]),
            .portScan
        )
    }
}
