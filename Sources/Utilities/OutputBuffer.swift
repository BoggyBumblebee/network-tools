import Foundation

struct OutputBuffer {
    static let maxLines = 10_000
    static let maxBytes = 1_048_576

    private(set) var lines: [String] = []
    private(set) var byteCount = 0
    private(set) var didTruncate = false

    mutating func clear() {
        lines.removeAll(keepingCapacity: true)
        byteCount = 0
        didTruncate = false
    }

    mutating func append(_ line: String) {
        lines.append(line)
        byteCount += line.utf8.count + 1

        var removedAny = false
        while lines.count > Self.maxLines || byteCount > Self.maxBytes {
            guard !lines.isEmpty else { break }
            let removed = lines.removeFirst()
            byteCount -= removed.utf8.count + 1
            removedAny = true
        }

        if removedAny {
            didTruncate = true
        }
    }

    var renderedText: String {
        var text = lines.joined(separator: "\n")
        if didTruncate {
            if !text.isEmpty {
                text.append("\n")
            }
            text.append("[output truncated: oldest lines removed]")
        }
        return text
    }
}
