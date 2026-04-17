import XCTest
import Darwin
@testable import NetworkTools

final class PortScanServiceTests: XCTestCase {
    func testRunReturnsFailedToResolveWhenResolverFails() async {
        let resolver = PortScanStubResolver(result: .failure(SocketOperationError.resolveFailure))
        let service = NativePortScanService(
            resolver: resolver,
            prober: DeterministicProber()
        )

        let reason = await service.run(
            configuration: PortScanConfiguration(
                destination: "invalid.local",
                mode: .range(from: 1, to: 3),
                timeoutMilliseconds: 100,
                concurrencyLimit: 1,
                progressEvery: 1
            ),
            onLine: { _ in }
        )

        XCTAssertEqual(reason, .failedToResolveHost)
    }

    func testRunCompletesAndReturnsSortedOpenPorts() async {
        let resolver = PortScanStubResolver(result: .success([portScanLocalhostAddress()]))
        let prober = DeterministicProber()
        prober.behaviors[5] = .success(0.5)
        prober.behaviors[3] = .success(0.3)
        prober.defaultBehavior = .failure(SocketOperationError.connectFailure("closed"))
        let service = NativePortScanService(
            resolver: resolver,
            prober: prober
        )

        let reason = await service.run(
            configuration: PortScanConfiguration(
                destination: "example.com",
                mode: .range(from: 3, to: 5),
                timeoutMilliseconds: 100,
                concurrencyLimit: 1,
                progressEvery: 1
            ),
            onLine: { _ in }
        )

        XCTAssertEqual(reason, .completed(totalScanned: 3, openPorts: [3, 5]))
    }

    func testRunReturnsStoppedByUserWhenCancelled() async {
        let resolver = PortScanStubResolver(result: .success([portScanLocalhostAddress()]))
        let prober = DeterministicProber()
        prober.delayMicroseconds = 25_000
        let service = NativePortScanService(
            resolver: resolver,
            prober: prober
        )

        let task = Task {
            await service.run(
                configuration: PortScanConfiguration(
                    destination: "example.com",
                    mode: .allPorts,
                    timeoutMilliseconds: 100,
                    concurrencyLimit: 8,
                    progressEvery: 1_000
                ),
                onLine: { _ in }
            )
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let reason = await task.value

        guard case .stoppedByUser(let scanned, _) = reason else {
            return XCTFail("Expected stoppedByUser, got \(reason)")
        }
        XCTAssertGreaterThan(scanned, 0)
        XCTAssertLessThan(scanned, 65_535)
    }
}

private final class PortScanStubResolver: IPv4AddressResolving, @unchecked Sendable {
    private let result: Result<[sockaddr_in], Error>

    init(result: Result<[sockaddr_in], Error>) {
        self.result = result
    }

    func resolveIPv4Addresses(host: String) throws -> [sockaddr_in] {
        try result.get()
    }
}

private final class DeterministicProber: TCPConnectProbing, @unchecked Sendable {
    private let lock = NSLock()
    var behaviors: [UInt16: Result<Double, SocketOperationError>] = [:]
    var defaultBehavior: Result<Double, SocketOperationError> = .success(0.1)
    var delayMicroseconds: useconds_t = 0

    func probe(addresses: [sockaddr_in], port: UInt16, timeoutMilliseconds: Int) throws -> Double {
        if delayMicroseconds > 0 {
            usleep(delayMicroseconds)
        }

        lock.lock()
        let result = behaviors[port] ?? defaultBehavior
        lock.unlock()
        return try result.get()
    }
}

private func portScanLocalhostAddress() -> sockaddr_in {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    _ = "127.0.0.1".withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
    return address
}
