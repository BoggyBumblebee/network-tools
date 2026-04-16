import XCTest
@testable import NetworkTools

final class PortScanViewModelTests: XCTestCase {
    @MainActor
    func testFiniteRangeValidationEnablesStart() {
        let viewModel = PortScanViewModel(service: RecordingPortScanService())
        viewModel.destination = "example.com"
        viewModel.scanAllPorts = false
        viewModel.fromPortText = "20"
        viewModel.toPortText = "25"

        XCTAssertEqual(viewModel.rangeValidation, 20...25)
        XCTAssertTrue(viewModel.isRangeValid)
        XCTAssertTrue(viewModel.canStart)
    }

    @MainActor
    func testInvalidRangeDisablesStartWhenNotScanningAllPorts() {
        let viewModel = PortScanViewModel(service: RecordingPortScanService())
        viewModel.destination = "example.com"
        viewModel.scanAllPorts = false
        viewModel.fromPortText = "443"
        viewModel.toPortText = "80"

        XCTAssertNil(viewModel.rangeValidation)
        XCTAssertFalse(viewModel.isRangeValid)
        XCTAssertFalse(viewModel.canStart)
    }

    @MainActor
    func testStartUsesParsedRangeWhenFiniteMode() async {
        let service = RecordingPortScanService()
        let viewModel = PortScanViewModel(service: service)
        viewModel.destination = "example.com"
        viewModel.scanAllPorts = false
        viewModel.fromPortText = "443"
        viewModel.toPortText = "445"

        viewModel.primaryAction()

        for _ in 0..<20 where viewModel.isRunning {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        let configuration = await service.lastConfiguration()
        XCTAssertEqual(configuration?.destination, "example.com")
        XCTAssertEqual(configuration?.mode, .range(from: 443, to: 445))
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.isCancelling)
        XCTAssertTrue(viewModel.outputText.contains("--- completed: scanned=3 open=1 ---"))
    }
}

private actor RecordingPortScanService: PortScanService {
    private var recordedConfiguration: PortScanConfiguration?

    func run(configuration: PortScanConfiguration, onLine: @escaping @Sendable (String) -> Void) async -> PortScanCompletionReason {
        recordedConfiguration = configuration
        onLine("scan started")
        return .completed(totalScanned: 3, openPorts: [443])
    }

    func lastConfiguration() -> PortScanConfiguration? {
        recordedConfiguration
    }
}
