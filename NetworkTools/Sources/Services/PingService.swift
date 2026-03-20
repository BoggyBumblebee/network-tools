import Foundation

protocol PingService {
    func run(configuration: PingConfiguration, onLine: @escaping @Sendable (String) -> Void) async -> PingCompletionReason
}

final class NativePingService: PingService {
    private let probePort: UInt16

    init(probePort: UInt16 = 443) {
        self.probePort = probePort
    }

    func run(configuration: PingConfiguration, onLine: @escaping @Sendable (String) -> Void) async -> PingCompletionReason {
        AppLogger.ping.info("Ping start destination=\(configuration.destination, privacy: .public)")
        onLine("PING \(configuration.destination)")

        let addresses: [sockaddr_in]
        do {
            addresses = try SocketResolver.resolveIPv4Addresses(host: configuration.destination)
        } catch {
            AppLogger.ping.error("Ping resolve failure destination=\(configuration.destination, privacy: .public)")
            return .failedToResolveHost
        }

        onLine("resolved \(addresses.count) address(es)")

        var sentCount = 0
        while !Task.isCancelled {
            if let count = configuration.count, sentCount >= count {
                AppLogger.ping.info("Ping completed requested count=\(count)")
                return .completedRequestedCount
            }

            sentCount += 1
            do {
                let rtt = try TCPConnectProbe.probe(
                    addresses: addresses,
                    port: probePort,
                    timeoutMilliseconds: Int(configuration.timeoutSeconds * 1_000.0)
                )
                onLine(String(format: "icmp_seq=%d time=%.2f ms", sentCount, rtt))
            } catch SocketOperationError.timeout {
                onLine("icmp_seq=\(sentCount) timeout")
            } catch SocketOperationError.socketFailure(let message) {
                AppLogger.ping.error("Ping socket failure=\(message, privacy: .public)")
                return .permissionOrNetworkingError(message)
            } catch SocketOperationError.connectFailure(let message) {
                onLine("icmp_seq=\(sentCount) connect_error=\(message)")
            } catch {
                return .timeoutOrOperationalFailure(String(describing: error))
            }

            if Task.isCancelled {
                break
            }

            if let count = configuration.count, sentCount >= count {
                AppLogger.ping.info("Ping completed requested count=\(count)")
                return .completedRequestedCount
            }

            do {
                try await Task.sleep(nanoseconds: UInt64(configuration.intervalSeconds * 1_000_000_000.0))
            } catch {
                break
            }
        }

        AppLogger.ping.info("Ping stopped by user")
        return .stoppedByUser
    }
}
