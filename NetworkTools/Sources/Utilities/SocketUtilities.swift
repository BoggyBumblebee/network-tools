import Darwin
import Foundation

enum SocketOperationError: Error, Equatable {
    case resolveFailure
    case timeout
    case connectFailure(String)
    case socketFailure(String)
}

protocol IPv4AddressResolving {
    func resolveIPv4Addresses(host: String) throws -> [sockaddr_in]
}

protocol TCPConnectProbing {
    func probe(addresses: [sockaddr_in], port: UInt16, timeoutMilliseconds: Int) throws -> Double
}

struct SystemIPv4AddressResolver: IPv4AddressResolving {
    func resolveIPv4Addresses(host: String) throws -> [sockaddr_in] {
        try SocketResolver.resolveIPv4Addresses(host: host)
    }
}

struct SystemTCPConnectProber: TCPConnectProbing {
    func probe(addresses: [sockaddr_in], port: UInt16, timeoutMilliseconds: Int) throws -> Double {
        try TCPConnectProbe.probe(addresses: addresses, port: port, timeoutMilliseconds: timeoutMilliseconds)
    }
}

enum SocketResolver {
    static func resolveIPv4Addresses(host: String) throws -> [sockaddr_in] {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )

        var resultPointer: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &resultPointer)
        guard status == 0, let head = resultPointer else {
            throw SocketOperationError.resolveFailure
        }

        defer { freeaddrinfo(head) }

        var addresses: [sockaddr_in] = []
        var cursor: UnsafeMutablePointer<addrinfo>? = head
        while let node = cursor {
            if node.pointee.ai_family == AF_INET,
               let aiAddr = node.pointee.ai_addr {
                let address = aiAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ptr in
                    ptr.pointee
                }
                addresses.append(address)
            }
            cursor = node.pointee.ai_next
        }

        guard !addresses.isEmpty else {
            throw SocketOperationError.resolveFailure
        }

        return addresses
    }
}

enum TCPConnectProbe {
    static func probe(addresses: [sockaddr_in], port: UInt16, timeoutMilliseconds: Int) throws -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        var lastError: SocketOperationError = .connectFailure("all addresses failed")

        for address in addresses {
            do {
                try connect(address: address, port: port, timeoutMilliseconds: timeoutMilliseconds)
                let end = DispatchTime.now().uptimeNanoseconds
                return Double(end - start) / 1_000_000.0
            } catch let error as SocketOperationError {
                lastError = error
                continue
            }
        }

        throw lastError
    }

    private static func connect(address: sockaddr_in, port: UInt16, timeoutMilliseconds: Int) throws {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
        }
        defer { close(sock) }

        let flags = fcntl(sock, F_GETFL, 0)
        if fcntl(sock, F_SETFL, flags | O_NONBLOCK) < 0 {
            throw SocketOperationError.socketFailure(String(cString: strerror(errno)))
        }

        var target = address
        target.sin_port = in_port_t(port).bigEndian

        let connectResult = withUnsafePointer(to: &target) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult == 0 {
            return
        }

        if errno != EINPROGRESS {
            throw SocketOperationError.connectFailure(String(cString: strerror(errno)))
        }

        var pollDescriptor = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
        let pollResult = Darwin.poll(&pollDescriptor, 1, Int32(timeoutMilliseconds))
        if pollResult == 0 {
            throw SocketOperationError.timeout
        }
        if pollResult < 0 {
            throw SocketOperationError.connectFailure(String(cString: strerror(errno)))
        }

        var socketError: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        if getsockopt(sock, SOL_SOCKET, SO_ERROR, &socketError, &length) < 0 {
            throw SocketOperationError.connectFailure(String(cString: strerror(errno)))
        }

        if socketError != 0 {
            if socketError == ETIMEDOUT {
                throw SocketOperationError.timeout
            }
            throw SocketOperationError.connectFailure(String(cString: strerror(socketError)))
        }
    }
}
