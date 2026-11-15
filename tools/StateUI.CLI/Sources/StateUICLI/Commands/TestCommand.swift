// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui test`: the suites a folder holds for a host, and one of them run.
struct TestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test", abstract: "Lists the suites this folder holds for a host, or runs one.", subcommands: [List.self, Run.self])

    /// `stateui test list [--host <host>]`.
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Lists the suites this folder holds for a host - plain Swift where none is named - in the order they are best run.")
        @Option(help: "The host; plain Swift when left out.")
        var host: HostFamily?
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            try await output.answer({ try await ToolingService().discoverTests(for: host, in: here) }) { (list: TestSuiteList) in
                list.suites.isEmpty ? "No suite here." : list.suites.map { "\($0.id) - \($0.detail)\($0.onDevice ? ", on a device" : "")" }.joined(separator: "\n")
            }
        }
    }

    /// `stateui test run --suite <id> [--host <host>] [--device <device>]`.
    struct Run: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Runs one suite this folder holds for a host, as stateui test list names it.")
        @Option(help: "The suite, as stateui test list names it.")
        var suite: String
        @Option(help: "The host; plain Swift when left out.")
        var host: HostFamily?
        @Option(help: "A suite on a device: UIKit's simulator, Android's device or emulator.")
        var device: String?
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            var passed = true
            try await output.answer({
                let ran = try await ToolingService().runTests(
                    TestRunRequest(suite: suite, host: host, device: device), in: here, reporter: BuildOptions.terminal)
                passed = ran.passed
                return ran
            }) { (ran: SuiteResult) in
                ran.phases.map { "\($0.passed ? "passed" : "FAILED")  \($0.name)" }.joined(separator: "\n")
            }
            if !passed { throw ExitCode(ExitStatus.of(ToolingError(.toolFailed, "the suite failed"))) }
        }
    }
}
