// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class ProjectCommandTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func folder(_ files: [String]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)").appendingPathComponent("Demo")
        for path in files {
            let file = folder.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "".write(to: file, atomically: true, encoding: .utf8)
        }
        return folder
    }

    /// `--format json` writes the project in its envelope; words name the root, each application and its hosts.
    func testAProjectIsDescribedInJSONAndInWords() async throws {
        let (outcome, output, _) = try await Stateui.run(
            "project", "describe", "--project", Self.repository.path, "--format", "json")
        XCTAssertTrue(outcome.succeeded)
        let envelope = try ToolingJSON.decoder().decode(Envelope<Project>.self, from: Data(output.joined(separator: "\n").utf8))
        XCTAssertEqual(envelope.result.applications.map(\.id), ["apps/Gallery", "apps/HelloWorld"])

        let (_, words, _) = try await Stateui.run("project", "describe", "--project", Self.repository.path)
        XCTAssertEqual(words.first, try FileURI.url(envelope.result.rootUri).path)
        XCTAssertEqual(words[2], "  apps/HelloWorld  appkit uikit android winui gtk web")
    }

    /// No project is a refusal: status 2, and in JSON the error's envelope alone on standard output.
    func testNoProjectIsRefusedWithStatus2() async throws {
        let empty = try folder(["notes.txt"])
        let (outcome, output, _) = try await Stateui.run("project", "describe", "--project", empty.path, "--format", "jsonl")
        XCTAssertEqual(outcome.termination, .exited(2))
        let envelope = try ToolingJSON.decoder().decode(ErrorEnvelope.self, from: Data(output.joined().utf8))
        XCTAssertEqual(envelope.error.code, .projectNotFound)
    }

    #if !os(Windows)
    /// An interrupt stops the command's work - the program it ran and every program that started - and the tool
    /// ends with status 130.
    func testAnInterruptStopsTheWorkAndEndsWith130() throws {
        let project = try folder(["Package.swift", "Platforms/AppKit/Package.swift"])
        try ApplicationFile(identifier: "com.example.demo", version: "1.0.0", build: 1)
            .write(to: project.appendingPathComponent("stateui.json"))
        let file = project.deletingLastPathComponent().appendingPathComponent("descendant")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Stateui.path)
        process.arguments = ["project", "describe", "--project", project.path]
        var environment = ProcessInfo.processInfo.environment
        environment["SWIFT_BIN"] = Stateui.probe
        environment["STATEUI_PROBE_FILE"] = file.path
        process.environment = environment
        process.standardError = FileHandle.nullDevice
        try process.run()

        let descendant = try Stateui.identifier(writtenTo: file)
        process.interrupt()
        let deadline = Date().addingTimeInterval(20)
        while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        XCTAssertFalse(process.isRunning, "the tool did not end")
        XCTAssertEqual(process.terminationStatus, 130)
        while Stateui.runs(descendant), Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        let alive = Stateui.runs(descendant)
        if alive { kill(descendant, SIGKILL) }
        XCTAssertFalse(alive, "a program the work started outlived the interrupt")
    }
    #endif
}
