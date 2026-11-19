// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

/// The tool asking another stateui over the protocol an editor speaks - here this build's own `stateui serve --stdio`,
/// as a guest's is asked through `prlctl exec`.
final class ServedToolTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func served(in folder: URL) -> ServedTool {
        ServedTool(executable: .path(Stateui.path), arguments: ["serve", "--stdio"], workspaceUri: FileURI.string(folder))
    }

    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("served-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// A served tool that ends before answering is said with what it last wrote to its standard error - a crash's own
    /// words, which the guest's tool otherwise takes with it.
    func testAServedToolThatEndsIsSaidWithItsLastWords() async throws {
        #if os(Windows)
        let dying = ServedTool(
            executable: .name("cmd.exe"), arguments: ["/c", "echo Fatal error: the guest broke 1>&2 & exit 1"], workspaceUri: "file:///C:/")
        #else
        let dying = ServedTool(
            executable: .path("/bin/sh"), arguments: ["-c", "echo 'Fatal error: the guest broke' >&2; exit 1"], workspaceUri: "file:///")
        #endif
        do {
            _ = try await dying.opening()
            XCTFail("a tool that ended answered")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .toolFailed)
            XCTAssertTrue(error.message.contains("Fatal error: the guest broke"), error.message)
        }
    }

    /// A query is answered with its result.
    func testAQueryIsAnswered() async throws {
        let info = try await served(in: try folder()).query("server/info", .object([:])).decode(ServerInfo.self)
        XCTAssertEqual(info.server.name, "stateui")
        XCTAssertEqual(info.server.version, Release.version)
    }

    /// A guest's own stateui is asked through `prlctl exec` as this build's is - where `STATEUI_TEST_GUEST` names a
    /// guest and `STATEUI_TEST_GUEST_STATEUI` the program in it; the answer is the guest's machine's.
    func testAGuestsToolIsAskedThroughParallels() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let guest = environment["STATEUI_TEST_GUEST"], let program = environment["STATEUI_TEST_GUEST_STATEUI"] else {
            throw XCTSkip("STATEUI_TEST_GUEST names no guest")
        }
        let tool = ServedTool(
            executable: .name("prlctl"), arguments: ["exec", guest, "--current-user", program, "serve", "--stdio"],
            workspaceUri: "file:///")
        let info = try await tool.query("server/info", .object([:])).decode(ServerInfo.self)
        XCTAssertEqual(info.server.name, "stateui")
        XCTAssertNotEqual(info.machine.system, Machine.current.system)
    }

    /// An operation is followed to its end and answers its result; one refused throws the served tool's own error.
    func testAnOperationAnswersItsResultAndARefusalItsError() async throws {
        let parent = try folder()
        let asked = { (name: String) in
            try JSONValue(encoding: ApplicationRequest(
                name: name, parentUri: FileURI.string(parent), checkoutUri: FileURI.string(Self.repository)))
        }
        let made = try await served(in: parent).operation("project/create", try asked("Probe"), reporter: BuildReporter())
        XCTAssertTrue(FileManager.default.fileExists(atPath: parent.appendingPathComponent("Probe/stateui.json").path), "\(made)")
        do {
            _ = try await served(in: parent).operation("project/create", try asked("2App"), reporter: BuildReporter())
            XCTFail("an application named 2App was made")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .invalidName)
        }
    }
}
