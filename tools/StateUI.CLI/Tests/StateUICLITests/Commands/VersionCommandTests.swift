// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class VersionCommandTests: XCTestCase {
    /// `--format json` writes one document on standard output and nothing else: the result in its envelope.
    func testJSONIsTheEnvelopeAlone() async throws {
        let (outcome, output, errors) = try await Stateui.run("version", "--format", "json")

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(errors, [])
        let envelope = try ToolingJSON.decoder().decode(
            Envelope<ServerInfo>.self, from: Data(output.joined(separator: "\n").utf8))
        XCTAssertEqual(envelope, Envelope(apiVersion: Release.newestAPIVersion, result: ToolingService().serverInfo()))
    }

    /// `--format jsonl` writes the envelope on one line.
    func testJSONLinesWriteTheEnvelopeOnOneLine() async throws {
        let (outcome, output, _) = try await Stateui.run("version", "--format", "jsonl")

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(output.count, 1)
        XCTAssertNoThrow(try ToolingJSON.decoder().decode(Envelope<ServerInfo>.self, from: Data(output[0].utf8)))
    }

    /// The words name the release, the API version and the machine.
    func testTextNamesTheReleaseTheAPIAndTheMachine() async throws {
        let (outcome, output, _) = try await Stateui.run("version")
        let machine = Machine.current

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(output, ["stateui \(Release.version), API 1.0, \(machine.system) \(machine.architecture)"])
    }

    /// A command line naming no command, or arguments a command does not take, ends with status 2.
    func testAnInvalidCommandLineEndsWithStatus2() async throws {
        for arguments in [[], ["version", "--format", "yaml"], ["no-such-command"]] {
            let (outcome, output, errors) = try await Stateui.run(arguments)
            XCTAssertEqual(outcome.termination, .exited(2), "\(arguments)")
            XCTAssertEqual(output, [], "\(arguments)")
            XCTAssertFalse(errors.isEmpty, "\(arguments)")
        }
    }

    /// Help is asked for, so it is no failure.
    func testHelpEndsWithStatus0() async throws {
        let (outcome, output, _) = try await Stateui.run("--help")
        XCTAssertTrue(outcome.succeeded)
        XCTAssertTrue(output.contains { $0.contains("version") })
    }
}
