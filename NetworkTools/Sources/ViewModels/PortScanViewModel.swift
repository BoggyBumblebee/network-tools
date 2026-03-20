import Combine
import Foundation

@MainActor
final class PortScanViewModel: ObservableObject {
    @Published var destination = ""
    @Published var scanAllPorts = false
    @Published var fromPortText = "1"
    @Published var toPortText = "1024"
    @Published private(set) var outputText = ""
    @Published private(set) var isRunning = false
    @Published private(set) var isCancelling = false

    private let service: PortScanService
    private var outputBuffer = OutputBuffer()
    private var runTask: Task<Void, Never>?
    private var activeRunID = UUID()

    init(service: PortScanService = NativePortScanService()) {
        self.service = service
    }

    deinit {
        runTask?.cancel()
    }

    var isDestinationValid: Bool {
        HostValidator.isValidDestination(destination)
    }

    var rangeValidation: ClosedRange<Int>? {
        NumericValidator.parsePortRange(from: fromPortText, to: toPortText)
    }

    var isRangeValid: Bool {
        scanAllPorts || rangeValidation != nil
    }

    var canStart: Bool {
        !isRunning && !isCancelling && isDestinationValid && isRangeValid
    }

    var primaryButtonLabel: String {
        isRunning ? "Stop" : "Scan"
    }

    func primaryAction() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    private func start() {
        guard canStart else { return }

        outputBuffer.clear()
        outputText = ""

        let runID = UUID()
        activeRunID = runID
        isRunning = true
        isCancelling = false

        let mode: PortScanMode
        if scanAllPorts {
            mode = .allPorts
        } else if let range = rangeValidation {
            mode = .range(from: range.lowerBound, to: range.upperBound)
        } else {
            return
        }

        let configuration = PortScanConfiguration(
            destination: destination,
            mode: mode,
            timeoutMilliseconds: 750,
            concurrencyLimit: 256,
            progressEvery: 250
        )

        runTask = Task { [weak self] in
            guard let self else { return }
            let reason = await service.run(configuration: configuration) { line in
                Task { @MainActor [weak self] in
                    self?.appendLine(line, runID: runID)
                }
            }

            await MainActor.run { [weak self] in
                self?.finish(reason: reason, runID: runID)
            }
        }
    }

    private func stop() {
        guard isRunning else { return }
        isRunning = false
        isCancelling = true
        runTask?.cancel()
    }

    private func finish(reason: PortScanCompletionReason, runID: UUID) {
        guard activeRunID == runID else { return }

        appendLine(reason.terminationLine, runID: runID)
        isRunning = false
        isCancelling = false
        runTask = nil
    }

    private func appendLine(_ line: String, runID: UUID) {
        guard activeRunID == runID else { return }
        outputBuffer.append(line)
        outputText = outputBuffer.renderedText
    }
}
