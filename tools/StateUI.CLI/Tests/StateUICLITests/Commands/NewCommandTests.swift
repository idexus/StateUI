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

final class NewCommandTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// The path from folder `from` to `to`, as a workspace file writes it.
    private func relativePath(from: URL, to: URL) throws -> String {
        let source = real(from).pathComponents, target = real(to).pathComponents
        var shared = 0
        while shared < min(source.count, target.count), source[shared] == target[shared] { shared += 1 }
        guard shared > 0 else { throw XCTSkip("the folders share no root") }
        return (Array(repeating: "..", count: source.count - shared) + target[shared...]).joined(separator: "/")
    }

    /// The real path of `url`: `/private` kept, as SwiftPM and the tool keep it.
    private func real(_ url: URL) -> URL {
        #if os(Windows)
        return url.resolvingSymlinksInPath()
        #else
        guard let resolved = realpath(url.path, nil) else { return url }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved))
        #endif
    }

    private func run(_ arguments: [String], in directory: URL) async throws -> (ProcessOutcome, [String]) {
        let output = Gathered()
        let request = ProcessRequest(.path(Stateui.path), arguments: arguments, workingDirectory: directory.path, timeout: .seconds(300))
        return (try await ProcessRunner().run(request, output: output.add), output.lines(of: .standardOutput))
    }

    /// `new` makes the application, answers with the project it stands as, and refuses a name or a folder taken.
    func testNewMakesAnApplicationAndRefusesWhatCannotBe() async throws {
        let parent = try folder()
        let base = ["--directory", parent.path, "--checkout", Self.repository.path, "--format", "json"]
        let (outcome, output) = try await run(["new", "Notes"] + base, in: parent)
        XCTAssertTrue(outcome.succeeded)
        let creation = try ToolingJSON.decoder().decode(Envelope<ProjectCreation>.self, from: Data(output.joined(separator: "\n").utf8))
        XCTAssertEqual(creation.result.project.applications.map(\.name), ["Notes"])

        let (taken, _) = try await run(["new", "Notes"] + base, in: parent)
        XCTAssertEqual(taken.termination, .exited(5))
        let (bad, _) = try await run(["new", "My-App"] + base, in: parent)
        XCTAssertEqual(bad.termination, .exited(2))
    }

    /// In a workspace, `new` makes the application in the working directory from the workspace's library, and lists
    /// it in the workspace's file.
    func testNewInAWorkspaceListsTheApplication() async throws {
        let workspace = try folder()
        let library = WorkspaceFile.LibraryReference(path: try relativePath(from: workspace, to: Self.repository))
        try WorkspaceFile(library: library, projects: [])
            .write(to: workspace.appendingPathComponent("stateui-workspace.json"))
        let clients = workspace.appendingPathComponent("clients")
        try FileManager.default.createDirectory(at: clients, withIntermediateDirectories: true)
        let (outcome, _) = try await run(["new", "Notes"], in: clients)
        XCTAssertTrue(outcome.succeeded)

        XCTAssertTrue(FileManager.default.fileExists(atPath: clients.appendingPathComponent("Notes/Package.swift").path))
        let file = try String(contentsOf: workspace.appendingPathComponent("stateui-workspace.json"), encoding: .utf8)
        XCTAssertTrue(file.contains("\"clients/Notes\""), file)
    }
}
