import Combine
import Foundation

@MainActor
final class PingViewModel: ObservableObject {
    @Published var destination = ""
    @Published var isUnlimited = false
    @Published var pingCountText = "10"
    @Published private(set) var outputText = ""
    @Published private(set) var isRunning = false
    @Published private(set) var isCancelling = false

    private let service: PingService
    private var outputBuffer = OutputBuffer()
    private var runTask: Task<Void, Never>?
    private var activeRunID = UUID()

    init(service: PingService = NativePingService()) {
        self.service = service
    }

    deinit {
        runTask?.cancel()
    }

    var isDestinationValid: Bool {
        HostValidator.isValidDestination(destination)
    }

    var isCountValid: Bool {
        isUnlimited || NumericValidator.isValidPingCount(pingCountText)
    }

    var primaryButtonLabel: String {
        isRunning ? "Stop" : "Ping"
    }

    var canStart: Bool {
        !isRunning && !isCancelling && isDestinationValid && isCountValid
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

        let count = isUnlimited ? nil : Int(pingCountText)
        let configuration = PingConfiguration(
            destination: destination,
            count: count,
            intervalSeconds: 1.0,
            timeoutSeconds: 2.0
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

    private func finish(reason: PingCompletionReason, runID: UUID) {
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
