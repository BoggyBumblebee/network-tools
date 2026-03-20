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
        XCTAssertEqual(viewModel.interfaceRows.first(where: { $0.label == "Link Speed" })?.value, "Unavailable")
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
}

private final class MockNetworkInterfaceService: NetworkInterfaceService {
    func listInterfaces() -> [NetworkInterfaceSummary] {
        [NetworkInterfaceSummary(name: "en0")]
    }

    func snapshot(for interfaceName: String) -> InterfaceSnapshot? {
        InterfaceSnapshot(
            name: interfaceName,
            hardwareAddress: nil,
            ipAddress: nil,
            linkSpeed: nil,
            transportSpeed: nil,
            linkStatus: .unknown,
            vendor: nil,
            model: nil,
            vendorID: "14e4",
            deviceID: "4434",
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
