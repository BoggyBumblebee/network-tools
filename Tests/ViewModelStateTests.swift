import XCTest
@testable import NetworkTools

final class ViewModelStateTests: XCTestCase {
    @MainActor
    func testPingViewModelStartStopStateTransitions() async {
        let viewModel = PingViewModel(service: SlowPingService())
        viewModel.destination = "example.com"
        viewModel.isUnlimited = true

        viewModel.primaryAction()
        XCTAssertTrue(viewModel.isRunning)

        viewModel.primaryAction()
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertTrue(viewModel.isCancelling)

        await assertEventuallyCancellingCompletes { viewModel.isCancelling }
        XCTAssertFalse(viewModel.isCancelling)
    }

    @MainActor
    func testPortScanViewModelStartStopStateTransitions() async {
        let viewModel = PortScanViewModel(service: SlowPortScanService())
        viewModel.destination = "example.com"
        viewModel.scanAllPorts = true

        viewModel.primaryAction()
        XCTAssertTrue(viewModel.isRunning)

        viewModel.primaryAction()
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertTrue(viewModel.isCancelling)

        await assertEventuallyCancellingCompletes { viewModel.isCancelling }
        XCTAssertFalse(viewModel.isCancelling)
    }

    @MainActor
    private func assertEventuallyCancellingCompletes(
        isCancelling: @MainActor () -> Bool,
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = ContinuousClock.now.advanced(by: .nanoseconds(Int64(timeoutNanoseconds)))

        while isCancelling() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Expected cancellation to finish before timeout.", file: file, line: line)
                return
            }

            await Task.yield()
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
    }
}

private final class SlowPingService: PingService {
    func run(configuration: PingConfiguration, onLine: @escaping @Sendable (String) -> Void) async -> PingCompletionReason {
        onLine("mock ping start")
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return .completedRequestedCount
        } catch {
            return .stoppedByUser
        }
    }
}

private final class SlowPortScanService: PortScanService {
    func run(configuration: PortScanConfiguration, onLine: @escaping @Sendable (String) -> Void) async -> PortScanCompletionReason {
        onLine("mock scan start")
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return .completed(totalScanned: 10, openPorts: [80, 443])
        } catch {
            return .stoppedByUser(scanned: 3, openPorts: [80])
        }
    }
}
