import XCTest
import SwiftUI
import AppKit
@testable import NetworkTools

final class ViewSmokeTests: XCTestCase {
    @MainActor
    func testInfoTabViewRendersInHostingView() {
        let viewModel = InfoViewModel(service: SmokeInterfaceService())
        viewModel.refreshForTesting()
        assertViewRenders(InfoTabView(viewModel: viewModel))
    }

    @MainActor
    func testPingTabViewRendersInHostingView() {
        let viewModel = PingViewModel(service: InstantPingService())
        viewModel.destination = "127.0.0.1"
        assertViewRenders(PingTabView(viewModel: viewModel))
    }

    @MainActor
    func testPingTabViewRendersWhenUnlimitedModeEnabled() {
        let viewModel = PingViewModel(service: InstantPingService())
        viewModel.destination = "127.0.0.1"
        viewModel.isUnlimited = true
        assertViewRenders(PingTabView(viewModel: viewModel))
    }

    @MainActor
    func testPingTabViewRendersWithInvalidCount() {
        let viewModel = PingViewModel(service: InstantPingService())
        viewModel.destination = "127.0.0.1"
        viewModel.pingCountText = "0"
        assertViewRenders(PingTabView(viewModel: viewModel))
    }

    @MainActor
    func testPortScanTabViewRendersInHostingView() {
        let viewModel = PortScanViewModel(service: InstantPortScanService())
        viewModel.destination = "127.0.0.1"
        viewModel.scanAllPorts = true
        assertViewRenders(PortScanTabView(viewModel: viewModel))
    }

    @MainActor
    func testPortScanTabViewRendersWithInvalidFiniteRange() {
        let viewModel = PortScanViewModel(service: InstantPortScanService())
        viewModel.destination = "127.0.0.1"
        viewModel.scanAllPorts = false
        viewModel.fromPortText = "9000"
        viewModel.toPortText = "1000"
        assertViewRenders(PortScanTabView(viewModel: viewModel))
    }

    @MainActor
    private func assertViewRenders<V: View>(_ view: V, file: StaticString = #filePath, line: UInt = #line) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 1_000, height: 600)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        XCTAssertGreaterThan(hostingView.fittingSize.width, 0, file: file, line: line)
        XCTAssertGreaterThan(hostingView.fittingSize.height, 0, file: file, line: line)
    }
}

private final class SmokeInterfaceService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        [NetworkInterfaceSummary(name: "en0", hardwareType: "Ethernet", isActive: true)]
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        InterfaceSnapshot(
            name: interfaceName,
            details: InterfaceSnapshot.Details(
                hardwareAddress: "00:11:22:33:44:55",
                ipAddress: "192.168.0.10",
                linkSpeed: nil,
                transportSpeed: "1 Gbps",
                linkStatus: .up,
                vendor: "Broadcom",
                model: "BCM57765",
                vendorID: "14e4",
                deviceID: "16b4"
            ),
            statistics: InterfaceStatistics(
                sentPackets: 1_000,
                sentBytes: 2_000_000,
                sendErrors: 0,
                receivedPackets: 2_000,
                receivedBytes: 3_000_000,
                receivedErrors: 0,
                collisions: 0
            )
        )
    }
}

private final class InstantPingService: PingService {
    func run(configuration: PingConfiguration, onLine: @escaping @Sendable (String) -> Void) async -> PingCompletionReason {
        onLine("PING \(configuration.destination)")
        return .completedRequestedCount
    }
}

private final class InstantPortScanService: PortScanService {
    func run(configuration: PortScanConfiguration, onLine: @escaping @Sendable (String) -> Void) async -> PortScanCompletionReason {
        onLine("scan target=\(configuration.destination)")
        return .completed(totalScanned: 0, openPorts: [])
    }
}
