import Foundation

enum PortScanMode: Equatable {
    case allPorts
    case range(from: Int, to: Int)
}

struct PortScanConfiguration: Equatable {
    let destination: String
    let mode: PortScanMode
    let timeoutMilliseconds: Int
    let concurrencyLimit: Int
    let progressEvery: Int
}

enum PortScanCompletionReason: Equatable {
    case completed(totalScanned: Int, openPorts: [Int])
    case stoppedByUser(scanned: Int, openPorts: [Int])
    case failedToResolveHost
    case failed(String)

    var terminationLine: String {
        switch self {
        case .completed(let totalScanned, let openPorts):
            return "--- completed: scanned=\(totalScanned) open=\(openPorts.count) ---"
        case .stoppedByUser(let scanned, let openPorts):
            return "--- stopped by user: scanned=\(scanned) open=\(openPorts.count) ---"
        case .failedToResolveHost:
            return "--- failed to resolve host ---"
        case .failed(let message):
            return "--- operational failure: \(message) ---"
        }
    }
}
