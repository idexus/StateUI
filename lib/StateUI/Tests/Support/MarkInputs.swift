// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The digest of the sources a host's conformance verdicts rest on, worked out as `.scripts/Marks/inputs.sh` works
/// it out: the git tree of the folders `.scripts/Marks/inputs.txt` names for every host and for this one, as they
/// stand in the working tree. A verdict file whose digest differs was made of other sources.
/// Design: docs/design/contracts/dictionary.md#fresh-verdicts
enum MarkInputs {
    /// What stops the digest being worked out.
    struct Unavailable: Error, CustomStringConvertible {
        let description: String
    }

    /// The folders `host`'s verdicts rest on - every host's, then its own - those that exist.
    static func folders(of host: String) throws -> [String] {
        let list = try String(
            contentsOf: SourceTree.repository.appendingPathComponent(".scripts/Marks/inputs.txt"), encoding: .utf8)
        var folders: [String] = []
        for line in list.split(separator: "\n") where !line.hasPrefix("#") {
            let words = line.split(separator: " ").map(String.init)
            guard let name = words.first, name == "every" || name == host else { continue }
            folders += words.dropFirst().filter {
                FileManager.default.fileExists(atPath: SourceTree.repository.appendingPathComponent($0).path)
            }
        }
        return folders
    }

    /// `host`'s digest now, each host's worked out once a run of the tests.
    static func digest(of host: String) throws -> String {
        if let known = digests[host] { return known }
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-marks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let index = scratch.appendingPathComponent("index").path
        _ = try git(["add", "-A", "--"] + folders(of: host), index: index)
        let digest = try git(["write-tree"], index: index).trimmingCharacters(in: .whitespacesAndNewlines)
        digests[host] = digest
        return digest
    }

    nonisolated(unsafe) private static var digests: [String: String] = [:]

    /// Runs git in the repository over the index at `index`, and answers what it printed.
    private static func git(_ arguments: [String], index: String) throws -> String {
        guard let git = executable("git") else { throw Unavailable(description: "no git on the PATH") }
        let process = Process()
        process.executableURL = git
        process.arguments = ["-C", SourceTree.repository.path] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_INDEX_FILE"] = index
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Unavailable(description: "git \(arguments.first ?? "") ended \(process.terminationStatus)")
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// The executable `name` on the PATH.
    private static func executable(_ name: String) -> URL? {
        let environment = ProcessInfo.processInfo.environment
        #if os(Windows)
        let (separator, file): (Character, String) = (";", name + ".exe")
        #else
        let (separator, file): (Character, String) = (":", name)
        #endif
        for folder in (environment["PATH"] ?? environment["Path"] ?? "").split(separator: separator) {
            let url = URL(fileURLWithPath: String(folder)).appendingPathComponent(file)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        return nil
    }
}
