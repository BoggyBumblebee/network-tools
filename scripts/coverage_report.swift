#!/usr/bin/swift

import Foundation

struct Options {
    let xcresultPath: String
    let repoRoot: String
    let exclusionsFile: String
    let overallThreshold: Double
    let changedThreshold: Double
    let diffBase: String?
    let sonarXMLPath: String?
}

struct XCCovReport: Decodable {
    let targets: [XCCovTarget]
}

struct XCCovTarget: Decodable {
    let files: [XCCovFile]?
}

struct XCCovFile: Decodable {
    let path: String
    let coveredLines: Int
    let executableLines: Int
}

struct CoveredFile {
    let absolutePath: String
    let relativePath: String
    let coveredLines: Int
    let executableLines: Int
}

struct LineCoverage {
    let lineNumber: Int
    let covered: Bool
}

enum CoverageError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let value):
            return value
        }
    }
}

let fileManager = FileManager.default

func main() throws {
    let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))
    let repoRootURL = URL(fileURLWithPath: options.repoRoot).standardizedFileURL
    let exclusions = try loadExclusions(from: options.exclusionsFile)

    let reportData = try runCommand(
        executable: "/usr/bin/xcrun",
        arguments: ["xccov", "view", "--report", "--json", options.xcresultPath]
    )
    let report = try JSONDecoder().decode(XCCovReport.self, from: reportData)
    let files = coveredFiles(from: report, repoRootURL: repoRootURL, exclusions: exclusions)

    guard !files.isEmpty else {
        throw CoverageError.message("No covered source files were found under \(repoRootURL.path).")
    }

    if let sonarXMLPath = options.sonarXMLPath {
        try writeSonarCoverageXML(for: files, xcresultPath: options.xcresultPath, outputPath: sonarXMLPath)
    }

    let overall = coverageRatio(covered: files.reduce(0) { $0 + $1.coveredLines },
                                executable: files.reduce(0) { $0 + $1.executableLines })

    print(String(format: "Overall executable-line coverage: %.2f%%", overall * 100))

    if overall + 0.000_001 < options.overallThreshold / 100 {
        throw CoverageError.message(String(
            format: "Overall coverage %.2f%% is below required threshold %.2f%%.",
            overall * 100,
            options.overallThreshold
        ))
    }

    if let diffBase = options.diffBase, !diffBase.isEmpty {
        let changedCoverage = try computeChangedCoverage(
            diffBase: diffBase,
            files: files,
            xcresultPath: options.xcresultPath
        )

        switch changedCoverage {
        case .none:
            print("Changed executable-line coverage: n/a (no changed executable lines)")
        case .some(let ratio):
            print(String(format: "Changed executable-line coverage: %.2f%%", ratio * 100))
            if ratio + 0.000_001 < options.changedThreshold / 100 {
                throw CoverageError.message(String(
                    format: "Changed coverage %.2f%% is below required threshold %.2f%%.",
                    ratio * 100,
                    options.changedThreshold
                ))
            }
        }
    } else {
        print("Changed executable-line coverage: skipped (no diff base provided)")
    }
}

func parseOptions(arguments: [String]) throws -> Options {
    var values: [String: String] = [:]
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]
        guard argument.hasPrefix("--") else {
            throw CoverageError.message("Unexpected argument: \(argument)")
        }

        guard index + 1 < arguments.count else {
            throw CoverageError.message("Missing value for \(argument)")
        }

        values[argument] = arguments[index + 1]
        index += 2
    }

    func required(_ key: String) throws -> String {
        guard let value = values[key], !value.isEmpty else {
            throw CoverageError.message("Missing required option \(key)")
        }
        return value
    }

    let overallThreshold = Double(try required("--overall-threshold")) ?? {
        return -1
    }()
    let changedThreshold = Double(try required("--changed-threshold")) ?? {
        return -1
    }()

    guard overallThreshold >= 0 else {
        throw CoverageError.message("Invalid numeric value for --overall-threshold")
    }

    guard changedThreshold >= 0 else {
        throw CoverageError.message("Invalid numeric value for --changed-threshold")
    }

    return Options(
        xcresultPath: try required("--xcresult"),
        repoRoot: try required("--repo-root"),
        exclusionsFile: try required("--exclusions-file"),
        overallThreshold: overallThreshold,
        changedThreshold: changedThreshold,
        diffBase: values["--diff-base"],
        sonarXMLPath: values["--sonar-xml"]
    )
}

func loadExclusions(from path: String) throws -> [String] {
    let url = URL(fileURLWithPath: path)
    guard fileManager.fileExists(atPath: url.path) else {
        return []
    }

    let contents = try String(contentsOf: url, encoding: .utf8)
    return contents
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

func coveredFiles(from report: XCCovReport, repoRootURL: URL, exclusions: [String]) -> [CoveredFile] {
    let rootPath = repoRootURL.path.hasSuffix("/") ? repoRootURL.path : repoRootURL.path + "/"
    var deduplicated: [String: CoveredFile] = [:]

    for target in report.targets {
        for file in target.files ?? [] {
            guard file.executableLines > 0 else { continue }
            guard file.path.hasPrefix(rootPath) else { continue }

            let relativePath = String(file.path.dropFirst(rootPath.count))
            guard !matchesAnyPattern(relativePath, patterns: exclusions) else { continue }

            if let existing = deduplicated[relativePath] {
                deduplicated[relativePath] = CoveredFile(
                    absolutePath: existing.absolutePath,
                    relativePath: existing.relativePath,
                    coveredLines: max(existing.coveredLines, file.coveredLines),
                    executableLines: max(existing.executableLines, file.executableLines)
                )
            } else {
                deduplicated[relativePath] = CoveredFile(
                    absolutePath: file.path,
                    relativePath: relativePath,
                    coveredLines: file.coveredLines,
                    executableLines: file.executableLines
                )
            }
        }
    }

    return deduplicated.values.sorted { $0.relativePath < $1.relativePath }
}

func matchesAnyPattern(_ path: String, patterns: [String]) -> Bool {
    patterns.contains { match(path: path, pattern: $0) }
}

func match(path: String, pattern: String) -> Bool {
    let normalizedPattern = NSRegularExpression.escapedPattern(for: pattern)
        .replacingOccurrences(of: "\\*\\*", with: ".*")
        .replacingOccurrences(of: "\\*", with: "[^/]*")
        .replacingOccurrences(of: "\\?", with: ".")

    let regexPattern = "^\(normalizedPattern)$"
    return path.range(of: regexPattern, options: .regularExpression) != nil
}

func writeSonarCoverageXML(for files: [CoveredFile], xcresultPath: String, outputPath: String) throws {
    var xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <coverage version="1">

    """

    for file in files {
        let lineCoverage = try loadLineCoverage(for: file.absolutePath, xcresultPath: xcresultPath)
        guard !lineCoverage.isEmpty else { continue }

        xml += "  <file path=\"\(escapeXML(file.relativePath))\">\n"
        for line in lineCoverage {
            let coveredValue = line.covered ? "true" : "false"
            xml += "    <lineToCover lineNumber=\"\(line.lineNumber)\" covered=\"\(coveredValue)\"/>\n"
        }
        xml += "  </file>\n"
    }

    xml += "</coverage>\n"
    try xml.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
}

func loadLineCoverage(for filePath: String, xcresultPath: String) throws -> [LineCoverage] {
    let data = try runCommand(
        executable: "/usr/bin/xcrun",
        arguments: ["xccov", "view", "--archive", "--file", filePath, xcresultPath]
    )

    let contents = String(decoding: data, as: UTF8.self)
    let pattern = #"^\s*(\d+):\s*(\*|\d+)"#
    let regex = try NSRegularExpression(pattern: pattern)
    var lines: [LineCoverage] = []

    for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = String(rawLine)
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let lineRange = Range(match.range(at: 1), in: line),
              let countRange = Range(match.range(at: 2), in: line),
              let lineNumber = Int(line[lineRange]) else {
            continue
        }

        let marker = String(line[countRange])
        if marker == "*" {
            continue
        }

        let executionCount = Int(marker) ?? 0
        lines.append(LineCoverage(lineNumber: lineNumber, covered: executionCount > 0))
    }

    return lines
}

func computeChangedCoverage(diffBase: String, files: [CoveredFile], xcresultPath: String) throws -> Double? {
    let data = try runCommand(
        executable: "/usr/bin/git",
        arguments: ["diff", "--unified=0", "\(diffBase)...HEAD", "--"]
    )
    let diff = String(decoding: data, as: UTF8.self)
    let changedLinesByFile = try parseChangedLines(from: diff)

    let fileLookup = Dictionary(uniqueKeysWithValues: files.map { ($0.relativePath, $0) })

    var covered = 0
    var executable = 0

    for (relativePath, changedLines) in changedLinesByFile {
        guard let file = fileLookup[relativePath] else { continue }
        let coverageByLine = Dictionary(uniqueKeysWithValues: try loadLineCoverage(
            for: file.absolutePath,
            xcresultPath: xcresultPath
        ).map { ($0.lineNumber, $0.covered) })

        for lineNumber in changedLines {
            guard let isCovered = coverageByLine[lineNumber] else { continue }
            executable += 1
            if isCovered {
                covered += 1
            }
        }
    }

    guard executable > 0 else {
        return nil
    }

    return coverageRatio(covered: covered, executable: executable)
}

func parseChangedLines(from diff: String) throws -> [String: Set<Int>] {
    var changedLinesByFile: [String: Set<Int>] = [:]
    var currentFile: String?

    let headerPattern = try NSRegularExpression(pattern: #"^\+\+\+ b/(.+)$"#)
    let hunkPattern = try NSRegularExpression(pattern: #"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@"#)

    for rawLine in diff.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = String(rawLine)
        let range = NSRange(line.startIndex..<line.endIndex, in: line)

        if let match = headerPattern.firstMatch(in: line, range: range),
           let fileRange = Range(match.range(at: 1), in: line) {
            let file = String(line[fileRange])
            currentFile = file == "/dev/null" ? nil : file
            continue
        }

        guard let file = currentFile,
              let match = hunkPattern.firstMatch(in: line, range: range),
              let startRange = Range(match.range(at: 1), in: line) else {
            continue
        }

        let start = Int(line[startRange]) ?? 0
        let count: Int
        if let countRange = Range(match.range(at: 2), in: line) {
            count = Int(line[countRange]) ?? 0
        } else {
            count = 1
        }

        guard count > 0 else { continue }
        changedLinesByFile[file, default: []].formUnion(start..<(start + count))
    }

    return changedLinesByFile
}

func coverageRatio(covered: Int, executable: Int) -> Double {
    guard executable > 0 else { return 1 }
    return Double(covered) / Double(executable)
}

func escapeXML(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

@discardableResult
func runCommand(executable: String, arguments: [String]) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
    let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

    guard process.terminationStatus == 0 else {
        let message = String(decoding: errorData.isEmpty ? outputData : errorData, as: UTF8.self)
        throw CoverageError.message(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return outputData
}

do {
    try main()
} catch {
    fputs("coverage_report.swift: \(error)\n", stderr)
    exit(1)
}
