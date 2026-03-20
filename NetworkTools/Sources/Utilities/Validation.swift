import Foundation

enum HostValidator {
    static func isValidDestination(_ input: String) -> Bool {
        isValidIPv4(input) || isValidHostname(input)
    }

    static func isValidIPv4(_ input: String) -> Bool {
        guard !input.isEmpty else { return false }
        let parts = input.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }

        for part in parts {
            guard let number = Int(part), part.allSatisfy({ $0.isNumber }), (0...255).contains(number) else {
                return false
            }
        }

        return true
    }

    static func isValidHostname(_ input: String) -> Bool {
        guard !input.isEmpty else { return false }
        guard input == input.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        guard !input.contains(" "), !input.contains("\t"), !input.contains("\n") else { return false }
        guard !input.hasSuffix(".") else { return false }
        guard input.count <= 253 else { return false }

        let labels = input.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }

        for label in labels {
            guard !label.isEmpty, label.count <= 63 else { return false }
            guard label.first != "-", label.last != "-" else { return false }
            for scalar in label.unicodeScalars {
                let isLetter = CharacterSet.letters.contains(scalar)
                let isDigit = CharacterSet.decimalDigits.contains(scalar)
                if !(isLetter || isDigit || scalar == "-") {
                    return false
                }
            }
        }

        return true
    }
}

enum NumericValidator {
    static func isValidPingCount(_ input: String) -> Bool {
        guard let value = Int(input), input.allSatisfy({ $0.isNumber }) else {
            return false
        }
        return (1...100).contains(value)
    }

    static func parsePortRange(from: String, to: String) -> ClosedRange<Int>? {
        guard
            let fromValue = Int(from),
            let toValue = Int(to),
            from.allSatisfy({ $0.isNumber }),
            to.allSatisfy({ $0.isNumber }),
            (1...65_535).contains(fromValue),
            (1...65_535).contains(toValue),
            fromValue <= toValue
        else {
            return nil
        }

        return fromValue...toValue
    }
}
