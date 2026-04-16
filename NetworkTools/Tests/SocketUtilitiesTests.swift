import XCTest
import Darwin
@testable import NetworkTools

final class SocketUtilitiesTests: XCTestCase {
    func testSystemIPv4AddressResolverResolvesLoopbackHost() throws {
        let resolver = SystemIPv4AddressResolver()

        let addresses = try resolver.resolveIPv4Addresses(host: "localhost")

        XCTAssertFalse(addresses.isEmpty)
        XCTAssertTrue(addresses.allSatisfy { $0.sin_family == sa_family_t(AF_INET) })
    }

    func testSystemTCPConnectProberReturnsRoundTripForLoopbackListener() throws {
        let listener = try LoopbackTCPListener()
        defer { listener.close() }

        let prober = SystemTCPConnectProber()
        let roundTrip = try prober.probe(
            addresses: [loopbackAddress()],
            port: listener.port,
            timeoutMilliseconds: 750
        )

        XCTAssertGreaterThanOrEqual(roundTrip, 0)
    }

    func testResolveIPv4AddressesForLoopbackHostReturnsAddresses() throws {
        let addresses = try SocketResolver.resolveIPv4Addresses(host: "localhost")

        XCTAssertFalse(addresses.isEmpty)
        XCTAssertTrue(addresses.allSatisfy { $0.sin_family == sa_family_t(AF_INET) })
    }

    func testResolveIPv4AddressesForUnknownHostThrowsResolveFailure() {
        XCTAssertThrowsError(try SocketResolver.resolveIPv4Addresses(host: "definitely-not-a-real-hostname.invalid")) {
            error in
            XCTAssertEqual(error as? SocketOperationError, .resolveFailure)
        }
    }

    func testProbeReturnsRoundTripTimeWhenLoopbackPortIsListening() throws {
        let listener = try LoopbackTCPListener()
        defer { listener.close() }

        let roundTrip = try TCPConnectProbe.probe(
            addresses: [loopbackAddress()],
            port: listener.port,
            timeoutMilliseconds: 750
        )

        XCTAssertGreaterThanOrEqual(roundTrip, 0)
    }

    func testProbeThrowsConnectFailureOrTimeoutWhenNoListenerExists() throws {
        let closedPort = try reserveLoopbackPort()

        XCTAssertThrowsError(
            try TCPConnectProbe.probe(
                addresses: [loopbackAddress()],
                port: closedPort,
                timeoutMilliseconds: 100
            )
        ) { error in
            guard let socketError = error as? SocketOperationError else {
                return XCTFail("Expected SocketOperationError, got \(error)")
            }

            switch socketError {
            case .connectFailure, .timeout:
                break
            default:
                XCTFail("Expected connectFailure or timeout, got \(socketError)")
            }
        }
    }
}

private final class LoopbackTCPListener {
    private var socketFileDescriptor: Int32
    let port: UInt16

    init() throws {
        let fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard fileDescriptor >= 0 else {
            throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
        }
        var shouldCloseFileDescriptor = true
        defer {
            if shouldCloseFileDescriptor {
                Darwin.close(fileDescriptor)
            }
        }

        var reuseAddress: Int32 = 1
        let setReuseResult = setsockopt(
            fileDescriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuseAddress,
            socklen_t(MemoryLayout.size(ofValue: reuseAddress))
        )
        guard setReuseResult == 0 else {
            throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
        }

        var address = loopbackAddress()
        address.sin_port = in_port_t(0).bigEndian

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
        }

        guard listen(fileDescriptor, 1) == 0 else {
            throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
        }

        var boundAddress = sockaddr_in()
        boundAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fileDescriptor, $0, &addressLength)
            }
        }
        guard nameResult == 0 else {
            throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
        }

        socketFileDescriptor = fileDescriptor
        port = UInt16(bigEndian: boundAddress.sin_port)
        shouldCloseFileDescriptor = false
    }

    deinit {
        close()
    }

    func close() {
        guard socketFileDescriptor >= 0 else { return }
        Darwin.close(socketFileDescriptor)
        socketFileDescriptor = -1
    }
}

private func reserveLoopbackPort() throws -> UInt16 {
    let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard socketFileDescriptor >= 0 else {
        throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
    }
    defer { Darwin.close(socketFileDescriptor) }

    var address = loopbackAddress()
    address.sin_port = in_port_t(0).bigEndian

    let bindResult = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.bind(socketFileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else {
        throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
    }

    var boundAddress = sockaddr_in()
    boundAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &boundAddress) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(socketFileDescriptor, $0, &addressLength)
        }
    }
    guard nameResult == 0 else {
        throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
    }

    return UInt16(bigEndian: boundAddress.sin_port)
}

private func loopbackAddress() -> sockaddr_in {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    _ = "127.0.0.1".withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
    return address
}
