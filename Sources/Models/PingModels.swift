import Foundation

struct PingConfiguration: Equatable {
    let destination: String
    let count: Int?
    let intervalSeconds: Double
    let timeoutSeconds: Double
}

enum PingCompletionReason: Equatable {
    case completedRequestedCount
    case stoppedByUser
    case failedToResolveHost
    case permissionOrNetworkingError(String)
    case timeoutOrOperationalFailure(String)

    var terminationLine: String {
        switch self {
        case .completedRequestedCount:
            return "--- completed requested count ---"
        case .stoppedByUser:
            return "--- stopped by user ---"
        case .failedToResolveHost:
            return "--- failed to resolve host ---"
        case .permissionOrNetworkingError(let message):
            return "--- permission or networking error: \(message) ---"
        case .timeoutOrOperationalFailure(let message):
            return "--- timeout or operational failure: \(message) ---"
        }
    }
}
