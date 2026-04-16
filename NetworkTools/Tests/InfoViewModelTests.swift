import XCTest
@testable import NetworkTools

final class InfoViewModelTests: XCTestCase {
    @MainActor
    func testUnavailableFallbackFormatting() {
        let service = MockNetworkInterfaceService()
        let viewModel = InfoViewModel(service: service)

        viewModel.refreshForTesting()

        XCTAssertEqual(viewModel.interfaces.map(\.name), ["en0"])
        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Hardware Address" })?.value, "Unavailable")
        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Link Speed" })?.value, "N/A")
        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Transport Speed" })?.value, "Unavailable")
        XCTAssertEqual(viewModel.statisticsRows.first(where: { $0.label == "Sent Data" })?.value, "Unavailable")
    }

    @MainActor
    func testIdentifiersAreShownWithoutDebugToggle() {
        let service = MockNetworkInterfaceService()
        let viewModel = InfoViewModel(service: service)

        viewModel.refreshForTesting()
        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Vendor" })?.value, "0x14e4")
        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Model" })?.value, "0x4434")
    }

    @MainActor
    func testDefaultsToEn0WhenAvailable() {
        let service = PreferredInterfaceOrderService()
        let viewModel = InfoViewModel(service: service)

        viewModel.refreshForTesting()

        XCTAssertEqual(viewModel.selectedInterfaceName, "en0")
    }

    @MainActor
    func testWiFiShowsLinkSpeedAndNotApplicableTransportSpeed() {
        let service = WiFiInterfaceService()
        let viewModel = InfoViewModel(service: service)

        viewModel.refreshForTesting()

        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Link Speed" })?.value, "866 Mbps")
        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Transport Speed" })?.value, "N/A")
    }

    @MainActor
    func testNoInterfacesShowsEmptyState() {
        let viewModel = InfoViewModel(service: EmptyInterfaceService())

        viewModel.refreshForTesting()

        XCTAssertTrue(viewModel.interfaces.isEmpty)
        XCTAssertEqual(viewModel.selectedInterfaceName, "")
        XCTAssertEqual(viewModel.emptyMessage, "No network interfaces are available.")
        XCTAssertTrue(viewModel.interfaceRows.isEmpty)
        XCTAssertTrue(viewModel.statisticsRows.isEmpty)
    }

    @MainActor
    func testSnapshotFailureShowsReadError() {
        let viewModel = InfoViewModel(service: SnapshotFailureService())

        viewModel.refreshForTesting()

        XCTAssertEqual(viewModel.selectedInterfaceName, "en4")
        XCTAssertEqual(viewModel.emptyMessage, "Unable to read interface details.")
        XCTAssertTrue(viewModel.interfaceRows.isEmpty)
        XCTAssertTrue(viewModel.statisticsRows.isEmpty)
    }

    @MainActor
    func testVendorAndModelRenderWithHexIdentifiers() {
        let viewModel = InfoViewModel(service: VendorModelService())

        viewModel.refreshForTesting()

        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Vendor" })?.value, "Intel (0x8086)")
        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Model" })?.value, "I225 (0x15f3)")
    }

    @MainActor
    func testWiFiAliasWithoutHyphenUsesWiFiSpeedRule() {
        let viewModel = InfoViewModel(service: WiFiAliasService())

        viewModel.refreshForTesting()

        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Link Speed" })?.value, "1.4 Gbps")
        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Transport Speed" })?.value, "N/A")
    }
}

private final class MockNetworkInterfaceService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        [NetworkInterfaceSummary(name: "en0", hardwareType: "Ethernet")]
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        InterfaceSnapshot(
            name: interfaceName,
            details: InterfaceSnapshot.Details(
                hardwareAddress: nil,
                ipAddress: nil,
                linkSpeed: nil,
                transportSpeed: nil,
                linkStatus: .unknown,
                vendor: nil,
                model: nil,
                vendorID: "14e4",
                deviceID: "4434"
            ),
            statistics: InterfaceStatistics(
                sentPackets: nil,
                sentBytes: nil,
                sendErrors: nil,
                receivedPackets: nil,
                receivedBytes: nil,
                receivedErrors: nil,
                collisions: nil
            )
        )
    }
}

private final class WiFiInterfaceService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        [NetworkInterfaceSummary(name: "en1", hardwareType: "Wi-Fi")]
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        InterfaceSnapshot(
            name: interfaceName,
            details: InterfaceSnapshot.Details(
                hardwareAddress: nil,
                ipAddress: nil,
                linkSpeed: "866 Mbps",
                transportSpeed: "1.2 Gbps",
                linkStatus: .up,
                vendor: nil,
                model: nil,
                vendorID: nil,
                deviceID: nil
            ),
            statistics: InterfaceStatistics(
                sentPackets: nil,
                sentBytes: nil,
                sendErrors: nil,
                receivedPackets: nil,
                receivedBytes: nil,
                receivedErrors: nil,
                collisions: nil
            )
        )
    }
}

private final class PreferredInterfaceOrderService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        [
            NetworkInterfaceSummary(name: "en2"),
            NetworkInterfaceSummary(name: "en0"),
            NetworkInterfaceSummary(name: "en1")
        ]
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        InterfaceSnapshot(
            name: interfaceName,
            details: InterfaceSnapshot.Details(
                hardwareAddress: nil,
                ipAddress: nil,
                linkSpeed: nil,
                transportSpeed: nil,
                linkStatus: .unknown,
                vendor: nil,
                model: nil,
                vendorID: nil,
                deviceID: nil
            ),
            statistics: InterfaceStatistics(
                sentPackets: nil,
                sentBytes: nil,
                sendErrors: nil,
                receivedPackets: nil,
                receivedBytes: nil,
                receivedErrors: nil,
                collisions: nil
            )
        )
    }
}

private final class EmptyInterfaceService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        []
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        nil
    }
}

private final class SnapshotFailureService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        [NetworkInterfaceSummary(name: "en4", hardwareType: "Ethernet")]
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        nil
    }
}

private final class VendorModelService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        [NetworkInterfaceSummary(name: "en0", hardwareType: "Ethernet")]
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        InterfaceSnapshot(
            name: interfaceName,
            details: InterfaceSnapshot.Details(
                hardwareAddress: "00:00:00:00:00:00",
                ipAddress: "192.168.1.2",
                linkSpeed: "1 Gbps",
                transportSpeed: "1 Gbps",
                linkStatus: .up,
                vendor: "Intel",
                model: "I225",
                vendorID: "8086",
                deviceID: "15f3"
            ),
            statistics: InterfaceStatistics(
                sentPackets: 1,
                sentBytes: 2,
                sendErrors: 0,
                receivedPackets: 3,
                receivedBytes: 4,
                receivedErrors: 0,
                collisions: 0
            )
        )
    }
}

private final class WiFiAliasService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        [NetworkInterfaceSummary(name: "en1", hardwareType: "WiFi")]
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        InterfaceSnapshot(
            name: interfaceName,
            details: InterfaceSnapshot.Details(
                hardwareAddress: nil,
                ipAddress: nil,
                linkSpeed: "1.4 Gbps",
                transportSpeed: "2.5 Gbps",
                linkStatus: .up,
                vendor: nil,
                model: nil,
                vendorID: nil,
                deviceID: nil
            ),
            statistics: InterfaceStatistics(
                sentPackets: nil,
                sentBytes: nil,
                sendErrors: nil,
                receivedPackets: nil,
                receivedBytes: nil,
                receivedErrors: nil,
                collisions: nil
            )
        )
    }
}
