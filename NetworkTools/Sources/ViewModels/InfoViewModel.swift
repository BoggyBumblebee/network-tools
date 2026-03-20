import Combine
import Foundation

@MainActor
final class InfoViewModel: ObservableObject {
    @Published private(set) var interfaces: [NetworkInterfaceSummary] = []
    @Published private(set) var selectedInterfaceName = ""
    @Published private(set) var interfaceRows: [DisplayRow] = []
    @Published private(set) var statisticsRows: [DisplayRow] = []
    @Published private(set) var emptyMessage: String?

    private let service: NetworkInterfaceService
    private var refreshTask: Task<Void, Never>?

    init(service: NetworkInterfaceService = SystemNetworkInterfaceService()) {
        self.service = service
    }

    deinit {
        refreshTask?.cancel()
    }

    func setInfoTabActive(_ isActive: Bool) {
        if isActive {
            startRefreshing()
        } else {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    func selectInterface(_ name: String) {
        selectedInterfaceName = name
        applySnapshot()
    }

    private func startRefreshing() {
        refreshTask?.cancel()

        refreshTask = Task { [weak self] in
            guard let self else { return }
            self.refreshNow()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                } catch {
                    return
                }
                self.refreshNow()
            }
        }
    }

    private func refreshNow() {
        interfaces = service.listInterfaces()

        guard !interfaces.isEmpty else {
            selectedInterfaceName = ""
            interfaceRows = []
            statisticsRows = []
            emptyMessage = "No network interfaces are available."
            AppLogger.info.error("No interfaces available")
            return
        }

        if !interfaces.contains(where: { $0.name == selectedInterfaceName }) {
            selectedInterfaceName = interfaces[0].name
        }

        emptyMessage = nil
        applySnapshot()
    }

    private func applySnapshot() {
        guard !selectedInterfaceName.isEmpty else {
            interfaceRows = []
            statisticsRows = []
            return
        }

        guard let snapshot = service.snapshot(for: selectedInterfaceName) else {
            emptyMessage = "Unable to read interface details."
            interfaceRows = []
            statisticsRows = []
            return
        }

        interfaceRows = [
            DisplayRow(label: "Hardware Address", value: Formatters.stringOrUnavailable(snapshot.hardwareAddress)),
            DisplayRow(label: "IP Address", value: Formatters.stringOrUnavailable(snapshot.ipAddress)),
            DisplayRow(label: "Link Speed", value: Formatters.stringOrUnavailable(snapshot.linkSpeed)),
            DisplayRow(label: "Transport Speed", value: Formatters.stringOrUnavailable(snapshot.transportSpeed)),
            DisplayRow(label: "Link Status", value: snapshot.linkStatus.displayValue),
            DisplayRow(label: "Vendor", value: Formatters.stringOrUnavailable(snapshot.vendor)),
            DisplayRow(label: "Model", value: Formatters.stringOrUnavailable(snapshot.model))
        ]

        statisticsRows = [
            DisplayRow(label: "Sent Packages", value: Formatters.numberOrUnavailable(snapshot.statistics.sentPackets)),
            DisplayRow(label: "Sent Data", value: Formatters.bytesOrUnavailable(snapshot.statistics.sentBytes)),
            DisplayRow(label: "Send Errors", value: Formatters.numberOrUnavailable(snapshot.statistics.sendErrors)),
            DisplayRow(label: "Received Packages", value: Formatters.numberOrUnavailable(snapshot.statistics.receivedPackets)),
            DisplayRow(label: "Received Data", value: Formatters.bytesOrUnavailable(snapshot.statistics.receivedBytes)),
            DisplayRow(label: "Received Errors", value: Formatters.numberOrUnavailable(snapshot.statistics.receivedErrors)),
            DisplayRow(label: "Collisions", value: Formatters.numberOrUnavailable(snapshot.statistics.collisions))
        ]
    }

    func refreshForTesting() {
        refreshNow()
    }
}
