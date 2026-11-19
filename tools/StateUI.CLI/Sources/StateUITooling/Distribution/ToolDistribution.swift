// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The tool's own distribution: its program built for release - the Swift runtime linked into it where the system
/// has none - in an archive with the project's license and NOTICE and the notices of the packages built into it, its
/// SHA-256 beside it; then the archive read back: what it holds, the libraries its program loads, and the program
/// answering from a folder of its own with no Swift on the search path.
/// Design: docs/design/tooling/repository.md#the-tools-distribution
struct ToolDistribution: Sendable {
    let checkout: URL
    let tools: ToolResolver

    /// The archive's name, with no extension: `stateui-0.8.5-macos-arm64`.
    static func name(of machine: Machine = .current) -> String {
        "stateui-\(Release.version)-\(machine.system)-\(machine.architecture)"
    }

    /// The program's file: `stateui.exe` on Windows.
    static var program: String {
        #if os(Windows)
        "stateui.exe"
        #else
        "stateui"
        #endif
    }

    /// What an archive holds, by path from its folder.
    static var contents: [String] { ["LICENSE", "NOTICE", "THIRD-PARTY-NOTICES", "bin/\(program)"] }

    /// Builds, archives and reads back the distribution into `output`, each a phase; the archive the result's artifact.
    func package(into output: URL, reporter: BuildReporter) async throws -> SuiteResult {
        let name = Self.name()
        let archive = output.appendingPathComponent(name + Self.archiveExtension)
        let staging = output.appendingPathComponent(name)
        let files = FileManager.default
        try? files.removeItem(at: staging)
        try? files.removeItem(at: archive)
        try files.createDirectory(at: staging.appendingPathComponent("bin"), withIntermediateDirectories: true)
        defer { try? files.removeItem(at: staging) }

        let package = checkout.appendingPathComponent("tools/StateUI.CLI")
        var placing = ["-c", "release", "--package-path", package.path, "--product", "stateui"]
        #if !os(macOS)
        placing.append("--static-swift-stdlib")
        #endif
        reporter.progress("building stateui \(Release.version) for release")
        guard try await run(tools.swift, ["build"] + placing, reporter: reporter) else {
            return SuiteResult(suite: "distribution", phases: [SuiteResult.Phase(name: "build", passed: false)])
        }
        let bin = try await ProductFolder.of(tools.swift, placing: placing)
        try files.copyItem(at: bin.appendingPathComponent(Self.program),
                           to: staging.appendingPathComponent("bin/\(Self.program)"))
        for file in ["LICENSE", "NOTICE"] {
            try files.copyItem(at: checkout.appendingPathComponent(file), to: staging.appendingPathComponent(file))
        }
        try Data(Self.notices(resolved: package.appendingPathComponent("Package.resolved"),
                              checkouts: package.appendingPathComponent(".build/checkouts")).utf8)
            .write(to: staging.appendingPathComponent("THIRD-PARTY-NOTICES"))

        reporter.progress("archiving \(archive.lastPathComponent)")
        let archived = try await run(.name("tar"), Self.archiveArguments(archive: archive, folder: output, name: name), reporter: reporter)
        if archived {
            let digest = SHA256.hex(try Data(contentsOf: archive))
            try Data("\(digest)  \(archive.lastPathComponent)\n".utf8).write(to: archive.appendingPathExtension("sha256"))
        }
        var phases = [SuiteResult.Phase(name: "build", passed: true), SuiteResult.Phase(name: "archive", passed: archived)]
        if archived {
            phases += try await readBack(archive, name: name, reporter: reporter)
        }
        return SuiteResult(suite: "distribution", phases: phases, artifactUri: FileURI.string(archive))
    }

    /// The archive unpacked in a folder of its own: what it holds, the libraries its program loads, its program run.
    private func readBack(_ archive: URL, name: String, reporter: BuildReporter) async throws -> [SuiteResult.Phase] {
        let files = FileManager.default
        let unpacked = files.temporaryDirectory.appendingPathComponent("stateui-distribution-\(UUID().uuidString)")
        try files.createDirectory(at: unpacked, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: unpacked) }
        guard try await run(.name("tar"), ["-xf", archive.path, "-C", unpacked.path], reporter: reporter) else {
            return [SuiteResult.Phase(name: "contents", passed: false)]
        }
        let folder = unpacked.appendingPathComponent(name)
        let held = (files.enumerator(atPath: folder.path)?.compactMap { $0 as? String } ?? [])
            .filter { !Self.isFolder(folder.appendingPathComponent($0)) }.map { $0.replacingOccurrences(of: "\\", with: "/") }.sorted()
        if held != Self.contents { reporter.progress("the archive holds \(held.joined(separator: ", "))") }
        let program = folder.appendingPathComponent("bin/\(Self.program)")
        let loaded = await Self.foreignLibraries(of: program)
        if !loaded.isEmpty { reporter.progress("the program loads \(loaded.joined(separator: ", "))") }
        let answer = await ToolOutput.standardOutput(.path(program.path), ["version"], environment: Self.bareEnvironment)
        return [
            SuiteResult.Phase(name: "contents", passed: held == Self.contents),
            SuiteResult.Phase(name: "libraries", passed: loaded.isEmpty),
            SuiteResult.Phase(name: "runs", passed: answer?.contains(Release.version) == true),
        ]
    }

    /// The notices of the packages `resolved` pins, each with its license and notice files as its checkout holds them.
    static func notices(resolved: URL, checkouts: URL) throws -> String {
        struct Resolved: Decodable {
            struct Pin: Decodable {
                struct State: Decodable { var version: String? }
                var identity: String
                var location: String
                var state: State
            }
            var pins: [Pin]
        }
        let pins = try JSONDecoder().decode(Resolved.self, from: Data(contentsOf: resolved)).pins.sorted { $0.identity < $1.identity }
        var text = """
            THIRD-PARTY NOTICES
            ===================

            The stateui program carries these packages, built into it. Where the system has no Swift runtime - Linux,
            Windows - it carries the Swift runtime too, under the Apache License 2.0 with its Runtime Library Exception.

            """
        for pin in pins {
            let folder = checkouts.appendingPathComponent(pin.identity)
            let files = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
                .filter { $0.uppercased().hasPrefix("LICENSE") || $0.uppercased().hasPrefix("NOTICE") }.sorted()
            guard !files.isEmpty else {
                throw ToolingError(.invalidConfiguration, "\(pin.identity) holds no license file in \(folder.path).")
            }
            text += "\n\n\(pin.identity) \(pin.state.version ?? "") - \(pin.location)\n\(String(repeating: "-", count: 60))\n"
            for file in files {
                text += "\n" + (try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8))
            }
        }
        return text
    }

    /// The libraries `program` loads from outside the system: none where the runtime is linked in.
    static func foreignLibraries(of program: URL) async -> [String] {
        #if os(macOS)
        let listed = await ToolOutput.standardOutput(.name("otool"), ["-L", program.path]) ?? "unread"
        return listed.split(separator: "\n").dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("/usr/lib/") && !$0.hasPrefix("/System/Library/") }
        #elseif os(Linux)
        let listed = await ToolOutput.standardOutput(.name("ldd"), [program.path]) ?? "unread"
        return listed.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in ["swift", "Foundation", "dispatch", "xml2", "unread"].contains { line.contains($0) } }
        #else
        return []
        #endif
    }

    /// An environment with no Swift: the search path without any folder of a toolchain, and no library path.
    static var bareEnvironment: ProcessEnvironment {
        let separator: Character = Machine.current.system == "windows" ? ";" : ":"
        let path = ProcessInfo.processInfo.environment.first { $0.key.uppercased() == "PATH" }?.value ?? ""
        let kept = path.split(separator: separator).filter { !$0.lowercased().contains("swift") && !$0.lowercased().contains("toolchain") }
        return ProcessEnvironment.inherited.removing("LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "SDKROOT")
            .setting("PATH", to: kept.joined(separator: String(separator)))
    }

    static var archiveExtension: String { Machine.current.system == "windows" ? ".zip" : ".tar.gz" }

    /// `tar`'s arguments making `archive` of `folder`'s `name`: a zip on Windows, its own tar's `-a`.
    static func archiveArguments(archive: URL, folder: URL, name: String) -> [String] {
        Machine.current.system == "windows"
            ? ["-a", "-cf", archive.path, "-C", folder.path, name] : ["-czf", archive.path, "-C", folder.path, name]
    }

    private static func isFolder(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func run(_ executable: ProcessExecutable, _ arguments: [String], reporter: BuildReporter) async throws -> Bool {
        try await ProcessRunner().run(ProcessRequest(executable, arguments: arguments), output: reporter.output).succeeded
    }
}
