import XCTest
import Darwin
@testable import NetworkTools

final class PingServiceTests: XCTestCase {
    func testRunReturnsFailedToResolveWhenResolverFails() async {
        let resolver = StubResolver(result: .failure(SocketOperationError.resolveFailure))
        let service = NativePingService(
            resolver: resolver,
            prober: SequencedProber([]),
            sleeper: { _ in }
        )

        let reason = await service.run(
            configuration: PingConfiguration(destination: "invalid.local", count: 1, intervalSeconds: 0, timeoutSeconds: 1),
            onLine: { _ in }
        )

        XCTAssertEqual(reason, .failedToResolveHost)
    }

    func testRunCompletesRequestedCountAndEmitsProbeLines() async {
        let resolver = StubResolver(result: .success([localhostAddress()]))
        let service = NativePingService(
            resolver: resolver,
            prober: SequencedProber([
                { 1.23 },
                { 2.34 }
            ]),
            sleeper: { _ in }
        )
        let lines = LockedLines()

        let reason = await service.run(
            configuration: PingConfiguration(destination: "example.com", count: 2, intervalSeconds: 0, timeoutSeconds: 1),
            onLine: { lines.append($0) }
        )

        XCTAssertEqual(reason, .completedRequestedCount)
        let output = lines.snapshot()
        XCTAssertTrue(output.contains("PING example.com"))
        XCTAssertTrue(output.contains("resolved 1 address(es)"))
        XCTAssertTrue(output.contains(where: { $0.contains("icmp_seq=1") }))
        XCTAssertTrue(output.contains(where: { $0.contains("icmp_seq=2") }))
    }

    func testRunReturnsPermissionErrorOnSocketFailure() async {
        let resolver = StubResolver(result: .success([localhostAddress()]))
        let service = NativePingService(
            resolver: resolver,
            prober: SequencedProber([{ throw SocketOperationError.socketFailure("permission denied") }]),
            sleeper: { _ in }
        )

        let reason = await service.run(
            configuration: PingConfiguration(destination: "example.com", count: 1, intervalSeconds: 0, timeoutSeconds: 1),
            onLine: { _ in }
        )

        XCTAssertEqual(reason, .permissionOrNetworkingError("permission denied"))
    }

    func testRunReportsTimeoutAndStillCompletesRequestedCount() async {
        let resolver = StubResolver(result: .success([localhostAddress()]))
        let service = NativePingService(
            resolver: resolver,
            prober: SequencedProber([{ throw SocketOperationError.timeout }]),
            sleeper: { _ in }
        )
        let lines = LockedLines()

        let reason = await service.run(
            configuration: PingConfiguration(destination: "example.com", count: 1, intervalSeconds: 0, timeoutSeconds: 1),
            onLine: { lines.append($0) }
        )

        XCTAssertEqual(reason, .completedRequestedCount)
        XCTAssertTrue(lines.snapshot().contains(where: { $0.contains("timeout") }))
    }

    func testRunReportsConnectFailureAndStillCompletesRequestedCount() async {
        let resolver = StubResolver(result: .success([localhostAddress()]))
        let service = NativePingService(
            resolver: resolver,
            prober: SequencedProber([{ throw SocketOperationError.connectFailure("connection refused") }]),
            sleeper: { _ in }
        )
        let lines = LockedLines()

        let reason = await service.run(
            configuration: PingConfiguration(destination: "example.com", count: 1, intervalSeconds: 0, timeoutSeconds: 1),
            onLine: { lines.append($0) }
        )

        XCTAssertEqual(reason, .completedRequestedCount)
        XCTAssertTrue(lines.snapshot().contains(where: { $0.contains("connect_error=connection refused") }))
    }

    func testRunReturnsStoppedByUserWhenCancelled() async {
        let resolver = StubResolver(result: .success([localhostAddress()]))
        let service = NativePingService(
            resolver: resolver,
            prober: SequencedProber([{ 0.2 }])
        )

        let task = Task {
            await service.run(
                configuration: PingConfiguration(destination: "example.com", count: nil, intervalSeconds: 5, timeoutSeconds: 1),
                onLine: { _ in }
            )
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let reason = await task.value

        XCTAssertEqual(reason, .stoppedByUser)
    }
}

private final class StubResolver: IPv4AddressResolving, @unchecked Sendable {
    private let result: Result<[sockaddr_in], Error>

    init(result: Result<[sockaddr_in], Error>) {
        self.result = result
    }

    func resolveIPv4Addresses(host: String) throws -> [sockaddr_in] {
        try result.get()
    }
}

private final class SequencedProber: TCPConnectProbing, @unchecked Sendable {
    private let lock = NSLock()
    private var probes: [() throws -> Double]

    init(_ probes: [() throws -> Double]) {
        self.probes = probes
    }

    func probe(addresses: [sockaddr_in], port: UInt16, timeoutMilliseconds: Int) throws -> Double {
        lock.lock()
        defer { lock.unlock() }
        guard !probes.isEmpty else {
            return 1.0
        }
        return try probes.removeFirst()()
    }
}

private final class LockedLines: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        let copy = values
        lock.unlock()
        return copy
    }
}

private func localhostAddress() -> sockaddr_in {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    _ = "127.0.0.1".withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
    return address
}
