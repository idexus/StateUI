// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import XCTest
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class ProcessRunnerTests: XCTestCase {
    override func setUp() async throws {
        XCTAssertTrue(FileManager.default.fileExists(atPath: Probe.path), "ProcessProbe is not built at \(Probe.path)")
    }

    /// Each argument reaches the program as written: no shell reads it, no space splits it, nothing expands.
    func testEachArgumentReachesTheProgramAsWritten() async throws {
        let written = [
            "zażółć gęślą jaźń", "two words", "\"quoted\"", "$HOME", "%PATH%", "*", "semi;colon", "a|b",
            #"back\slash"#, #"ends with a backslash\"#, #"quote after backslash\"x"#, "tab\there",
        ]
        var request = Probe.request("arguments")
        request.arguments += written
        let (outcome, lines) = try await Probe.run(request)

        XCTAssertEqual(outcome, ProcessOutcome(termination: .exited(0)))
        let read = try JSONDecoder().decode([String].self, from: Data(lines.of(.standardOutput).joined().utf8))
        XCTAssertEqual(read, written)
    }

    /// An empty argument reaches the program as one; on Windows, whose command line would lose it, the run is
    /// refused rather than the program given fewer arguments than written.
    func testAnEmptyArgumentReachesTheProgramOrTheRunIsRefused() async throws {
        let request = Probe.request("arguments", "before", "", "after")
        #if os(Windows)
        do {
            _ = try await ProcessRunner().run(request)
            XCTFail("the program ran without its empty argument")
        } catch let failure as ProcessFailure {
            XCTAssertEqual(failure, .emptyArgument)
        }
        #else
        let (_, lines) = try await Probe.run(request)
        let read = try JSONDecoder().decode([String].self, from: Data(lines.of(.standardOutput).joined().utf8))
        XCTAssertEqual(read, ["before", "", "after"])
        #endif
    }

    /// The program inherits this tool's environment, less what the request removes, with what it sets.
    func testTheEnvironmentIsInheritedLessWhatIsRemovedWithWhatIsSet() async throws {
        TestEnvironment.set("STATEUI_CLI_TEST_INHERITED", "kept")
        TestEnvironment.set("STATEUI_CLI_TEST_REMOVED", "appkit")
        var request = Probe.request(
            "environment", "STATEUI_CLI_TEST_INHERITED", "STATEUI_CLI_TEST_REMOVED", "STATEUI_CLI_TEST_SET")
        request.environment = ProcessEnvironment.inherited
            .removing("STATEUI_CLI_TEST_REMOVED")
            .setting("STATEUI_CLI_TEST_SET", to: "żółw")
        let (_, lines) = try await Probe.run(request)

        let read = try JSONDecoder().decode(
            [String: String?].self, from: Data(lines.of(.standardOutput).joined().utf8))
        XCTAssertEqual(read["STATEUI_CLI_TEST_INHERITED"], "kept")
        XCTAssertEqual(read["STATEUI_CLI_TEST_REMOVED"], .some(nil))
        XCTAssertEqual(read["STATEUI_CLI_TEST_SET"], "żółw")
    }

    /// The program starts in the directory given, spaces and all.
    func testTheProgramStartsInTheDirectoryGiven() async throws {
        let directory = try Probe.directory("Zażółć gęślą jaźń")
        var request = Probe.request("directory")
        request.workingDirectory = directory.path
        let (outcome, lines) = try await Probe.run(request)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(
            URL(fileURLWithPath: lines.of(.standardOutput).joined()).resolvingSymlinksInPath().path,
            directory.resolvingSymlinksInPath().path)
    }

    /// Both streams are read at once, so a program filling them both runs to its end.
    func testBothStreamsAreReadAtOnce() async throws {
        let (outcome, lines) = try await Probe.run(Probe.request("flood", "20000"))

        XCTAssertEqual(outcome, ProcessOutcome(termination: .exited(0)))
        XCTAssertEqual(lines.of(.standardOutput).count, 20000)
        XCTAssertEqual(lines.of(.standardError).count, 20000)
        XCTAssertEqual(lines.of(.standardOutput).last?.hasPrefix("out 19999 "), true)
    }

    /// A line longer than the longest given whole comes in pieces, and the run goes on.
    func testALongLineComesInPiecesAndTheRunGoesOn() async throws {
        let (outcome, lines) = try await Probe.run(Probe.request("line", "300000"))

        XCTAssertTrue(outcome.succeeded)
        let output = lines.of(.standardOutput)
        XCTAssertEqual(output.last, "done")
        XCTAssertEqual(output.dropLast().joined().count, 300000)
        XCTAssertGreaterThan(output.count, 2)
    }

    /// The outcome carries the program's own exit status.
    func testTheOutcomeCarriesTheProgramsExitStatus() async throws {
        let (outcome, _) = try await Probe.run(Probe.request("exit", "3"))
        XCTAssertEqual(outcome, ProcessOutcome(termination: .exited(3)))
        XCTAssertFalse(outcome.succeeded)
    }

    #if !os(Windows)
    /// A signal that ends the program is its termination.
    func testASignalEndingTheProgramIsItsTermination() async throws {
        let (outcome, _) = try await Probe.run(Probe.request("abort"))
        XCTAssertEqual(outcome, ProcessOutcome(termination: .signaled(Int(SIGABRT))))
    }
    #endif

    /// A program that is not there is not found, by path and by name.
    func testAMissingProgramIsNotFound() async throws {
        for executable in [ProcessExecutable.path("/no/such/stateui-program"), .name("stateui-no-such-program")] {
            do {
                _ = try await ProcessRunner().run(ProcessRequest(executable))
                XCTFail("\(executable) ran")
            } catch let failure as ProcessFailure {
                guard case .notFound = failure else { return XCTFail("\(executable): \(failure)") }
            }
        }
    }

    /// A working directory that is not there makes the run fail before the program starts.
    func testAMissingDirectoryIsUnusable() async throws {
        var request = Probe.request("directory")
        request.workingDirectory = try Probe.directory().appendingPathComponent("absent").path
        do {
            _ = try await ProcessRunner().run(request)
            XCTFail("the program ran")
        } catch let failure as ProcessFailure {
            guard case .directoryUnusable = failure else { return XCTFail("\(failure)") }
        }
    }

    /// A program past its time limit is stopped with every program it started, and the run says so.
    func testATimeoutStopsTheProgramAndEveryProgramItStarted() async throws {
        let file = try Probe.directory().appendingPathComponent("descendant")
        let started = ContinuousClock.now
        let (outcome, _) = try await Probe.run(
            Probe.request("descendant", file.path, "holds", "stays", timeout: .seconds(3)))

        XCTAssertEqual(outcome.stop, .timeout)
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(15))
        let descendant = try await Probe.identifier(writtenTo: file)
        let gone = try await Probe.waitUntilGone(descendant)
        if !gone { Probe.end(descendant) }
        XCTAssertTrue(gone, "the program the probe started outlived the stop")
    }

    /// Cancelling the task running a program stops it with every program it started.
    func testCancellingStopsTheProgramAndEveryProgramItStarted() async throws {
        let file = try Probe.directory().appendingPathComponent("descendant")
        let run = Task { try await Probe.run(Probe.request("descendant", file.path, "quiet", "stays")) }
        let descendant = try await Probe.identifier(writtenTo: file)
        run.cancel()
        let (outcome, _) = try await run.value

        XCTAssertEqual(outcome.stop, .cancellation)
        let gone = try await Probe.waitUntilGone(descendant)
        if !gone { Probe.end(descendant) }
        XCTAssertTrue(gone, "the program the probe started outlived the cancellation")
    }

    #if !os(Windows)
    /// A program deaf to the request to stop is killed once its grace period passes.
    func testAProgramDeafToTheRequestToStopIsKilled() async throws {
        var request = Probe.request("deaf", timeout: .seconds(2))
        request.gracePeriod = .milliseconds(500)
        let started = ContinuousClock.now
        let (outcome, lines) = try await Probe.run(request)

        XCTAssertEqual(lines.of(.standardOutput), ["deaf"])
        XCTAssertEqual(outcome, ProcessOutcome(termination: .signaled(Int(SIGKILL)), stop: .timeout))
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(10))
    }
    #endif

    /// A program that ends while a program it started still holds its output ends the run; what it started stays.
    func testAProgramsEndEndsTheRunThoughADescendantHoldsItsOutput() async throws {
        let file = try Probe.directory().appendingPathComponent("descendant")
        let started = ContinuousClock.now
        let (outcome, _) = try await Probe.run(Probe.request("descendant", file.path, "holds", "leaves"))
        let descendant = try await Probe.identifier(writtenTo: file)
        defer { Probe.end(descendant) }

        XCTAssertEqual(outcome, ProcessOutcome(termination: .exited(0)))
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(15))
        XCTAssertTrue(Probe.isRunning(descendant), "a program's own end leaves what it started")
    }

    #if !os(Windows)
    /// A program run on the terminal writes to this tool's own standard output.
    func testATerminalProgramSharesTheStandardStreams() async throws {
        let file = try Probe.directory().appendingPathComponent("streams")
        var request = Probe.request("streams", file.path)
        request.streams = .terminal
        let (outcome, _) = try await Probe.run(request)

        var status = stat()
        fstat(1, &status)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "\(status.st_dev):\(status.st_ino)")
    }
    #endif

}
