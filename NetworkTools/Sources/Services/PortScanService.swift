import Foundation

protocol PortScanService {
    func run(configuration: PortScanConfiguration, onLine: @escaping @Sendable (String) -> Void) async -> PortScanCompletionReason
}

final class NativePortScanService: PortScanService {
    private let resolver: IPv4AddressResolving
    private let prober: TCPConnectProbing

    init(
        resolver: IPv4AddressResolving = SystemIPv4AddressResolver(),
        prober: TCPConnectProbing = SystemTCPConnectProber()
    ) {
        self.resolver = resolver
        self.prober = prober
    }

    private actor PortSequence {
        private var current: Int
        private let end: Int

        init(range: ClosedRange<Int>) {
            current = range.lowerBound
            end = range.upperBound
        }

        func next() -> Int? {
            guard current <= end else { return nil }
            let value = current
            current += 1
            return value
        }
    }

    private actor ScanAccumulator {
        private var attempted = 0
        private var openPorts: [Int] = []
        private let total: Int
        private let progressEvery: Int
        private let onLine: @Sendable (String) -> Void

        init(total: Int, progressEvery: Int, onLine: @escaping @Sendable (String) -> Void) {
            self.total = total
            self.progressEvery = max(progressEvery, 1)
            self.onLine = onLine
        }

        func record(port: Int, isOpen: Bool) {
            attempted += 1
            if isOpen {
                openPorts.append(port)
                onLine("open \(port)/tcp")
            }
            if attempted % progressEvery == 0 || attempted == total {
                onLine("progress \(attempted)/\(total)")
            }
        }

        func snapshot() -> (attempted: Int, openPorts: [Int]) {
            (attempted, openPorts.sorted())
        }
    }

    func run(configuration: PortScanConfiguration, onLine: @escaping @Sendable (String) -> Void) async -> PortScanCompletionReason {
        let range = configuredRange(for: configuration.mode)
        let total = range.count

        AppLogger.scan.info(
            "Scan start destination=\(configuration.destination, privacy: .public) range=\(range.lowerBound)-\(range.upperBound)"
        )
        onLine("scan target=\(configuration.destination) range=\(range.lowerBound)-\(range.upperBound)")
        onLine("timeout=\(configuration.timeoutMilliseconds)ms concurrency=\(configuration.concurrencyLimit)")

        let addresses: [sockaddr_in]
        do {
            addresses = try resolver.resolveIPv4Addresses(host: configuration.destination)
        } catch {
            AppLogger.scan.error("Scan resolve failure destination=\(configuration.destination, privacy: .public)")
            return .failedToResolveHost
        }

        let sequence = PortSequence(range: range)
        let accumulator = ScanAccumulator(total: total, progressEvery: configuration.progressEvery, onLine: onLine)
        let workerCount = min(max(configuration.concurrencyLimit, 1), max(total, 1))

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<workerCount {
                group.addTask {
                    while !Task.isCancelled {
                        guard let port = await sequence.next() else {
                            return
                        }

                        let isOpen: Bool
                        do {
                            _ = try self.prober.probe(
                                addresses: addresses,
                                port: UInt16(port),
                                timeoutMilliseconds: configuration.timeoutMilliseconds
                            )
                            isOpen = true
                        } catch {
                            isOpen = false
                        }

                        await accumulator.record(port: port, isOpen: isOpen)
                    }
                }
            }

            await group.waitForAll()
        }

        let snapshot = await accumulator.snapshot()

        if Task.isCancelled {
            AppLogger.scan.info("Scan stopped by user scanned=\(snapshot.attempted)")
            return .stoppedByUser(scanned: snapshot.attempted, openPorts: snapshot.openPorts)
        }

        AppLogger.scan.info("Scan completed scanned=\(snapshot.attempted) open=\(snapshot.openPorts.count)")
        return .completed(totalScanned: snapshot.attempted, openPorts: snapshot.openPorts)
    }

    private func configuredRange(for mode: PortScanMode) -> ClosedRange<Int> {
        switch mode {
        case .allPorts:
            return 1...65_535
        case .range(let from, let to):
            return from...to
        }
    }
}
