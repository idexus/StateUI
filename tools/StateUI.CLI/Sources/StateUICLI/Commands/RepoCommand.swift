// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui repo`: the StateUI checkout's own work - its suites.
struct RepoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repo", abstract: "Works on a StateUI checkout itself.", subcommands: [Test.self])

    /// `stateui repo test --suite host:<host>`.
    struct Test: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Runs a suite of the checkout's own: host:appkit or host:uikit - the host's tests, every conformance verdict held, then its API records.")

        @Option(help: "The suite: host:appkit or host:uikit.")
        var suite: String

        @Option(help: "host:uikit's simulator, by name or UDID; the booted one, else an iPhone, when left out.")
        var device: String?

        @Option(help: "Only the tests whose names this matches, as swift test --filter takes it.")
        var filter: String?

        @OptionGroup var output: OutputOptions

        func run() async throws {
            let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            var passed = true
            try await output.answer({
                let ran = try await ToolingService().testSuite(suite, filter: filter, device: device, in: here, reporter: BuildOptions.terminal)
                passed = ran.passed
                return ran
            }) { (ran: SuiteResult) in
                ran.phases.map { "\($0.passed ? "passed" : "FAILED")  \($0.name)" }.joined(separator: "\n")
            }
            if !passed { throw ExitCode(ExitStatus.of(ToolingError(.toolFailed, "the suite failed"))) }
        }
    }
}
