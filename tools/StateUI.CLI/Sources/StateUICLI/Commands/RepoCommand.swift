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
            abstract: "Runs a suite of the checkout's own: host:appkit, host:uikit, host:android, host:gtk or host:web - the host's tests, every conformance verdict held, then its API records; sizes:web, the release Web modules' size budgets.")

        @Option(help: "The suite: host:appkit, host:uikit, host:android, host:gtk, host:web or sizes:web.")
        var suite: String

        @Option(help: "host:uikit's simulator, by name or UDID - the booted one, else an iPhone, when left out; host:android's device or emulator.")
        var device: String?

        @Flag(help: "host:android: build the test APK alone, with its identity, and say its folder - to run elsewhere with --artifact.")
        var buildOnly = false

        @Option(help: "host:android with --build-only: the architecture the test APK is built for, arm64 or x86_64.")
        var architecture: Architecture?

        @Option(help: "host:android: run the test APK a --build-only made, from its folder, instead of building one.")
        var artifact: String?

        @Option(help: "Only the tests whose names this matches, as swift test --filter takes it.")
        var filter: String?

        @OptionGroup var output: OutputOptions

        func run() async throws {
            let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            var passed = true
            try await output.answer({
                let ran = try await ToolingService().testSuite(
                    suite, filter: filter, device: device, buildOnly: buildOnly, architecture: architecture,
                    artifact: artifact.map { URL(fileURLWithPath: $0) }, in: here, reporter: BuildOptions.terminal)
                passed = ran.passed
                return ran
            }) { (ran: SuiteResult) in
                (ran.phases.map { "\($0.passed ? "passed" : "FAILED")  \($0.name)" }
                    + (ran.artifactUri.map { ["built   \((try? FileURI.url($0).path) ?? $0)"] } ?? [])).joined(separator: "\n")
            }
            if !passed { throw ExitCode(ExitStatus.of(ToolingError(.toolFailed, "the suite failed"))) }
        }
    }
}
