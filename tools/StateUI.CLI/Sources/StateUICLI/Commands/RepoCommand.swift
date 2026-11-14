// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui repo`: the StateUI checkout's own work - its suites.
struct RepoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repo", abstract: "Works on a StateUI checkout itself.", subcommands: [Test.self, Conformance.self])

    /// `stateui repo test --suite host:<host>`.
    struct Test: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Runs a suite of the checkout's own: host:appkit, host:uikit, host:android, host:winui, host:gtk or host:web - the host's tests, every conformance verdict held, then its API records; sizes:web, the release Web modules' size budgets.")

        @Option(help: "The suite: host:appkit, host:uikit, host:android, host:winui, host:gtk, host:web or sizes:web.")
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

    /// `stateui repo conformance`: the hosts' conformance verdicts.
    struct Conformance: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Works on the hosts' conformance verdicts.", subcommands: [Status.self, Run.self])

        /// `stateui repo conformance status [--host <host>]`.
        struct Status: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Says where each host's conformance verdicts stand: fresh, stale, missing or unreadable, family by family.")

            @Option(help: "The host; every host where left out.")
            var host: HostFamily?

            @OptionGroup var output: OutputOptions

            func run() async throws {
                let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                try await output.answer({
                    try await ToolingService().conformanceStatus(of: host.map { [$0] } ?? [], in: here, reporter: BuildOptions.terminal)
                }) { (statuses: [ConformanceStatus]) in
                    statuses.map { status in
                        let behind = status.stale.map { "\($0.name) (\($0.status.rawValue), at \($0.files.compactMap(\.revision).joined(separator: " ")), owes \($0.revision))" }
                        return "\(status.host.rawValue): \(status.families.count - behind.count) of \(status.families.count) fresh"
                            + (behind.isEmpty ? "" : "\n  " + behind.joined(separator: "\n  "))
                    }.joined(separator: "\n")
                }
            }
        }
    
        /// `stateui repo conformance run --host <host> (--changed | --family <name>... | --all) [--record]`.
        struct Run: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Runs a host's conformance families whole - the stale ones, the ones named or every one - holding their verdicts to the marks, or recording them and rendering the dictionary.")

            @Option(help: "The host.")
            var host: HostFamily

            @Flag(help: "The families whose verdicts stand at another revision, or at none.")
            var changed = false

            @Option(help: "A family, by name; one option a family.")
            var family: [String] = []

            @Flag(help: "Every family.")
            var all = false

            @Flag(help: "Write the verdicts into lib/StateUI/exports/marks and render the control dictionary and the platform contract from them, instead of holding them.")
            var record = false

            @Option(help: "UIKit's simulator or Android's device or emulator, by name or id.")
            var device: String?

            @OptionGroup var output: OutputOptions

            func validate() throws {
                guard [changed, !family.isEmpty, all].filter({ $0 }).count == 1 else {
                    throw ValidationError("Name exactly one of --changed, --family or --all.")
                }
            }

            func run() async throws {
                let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                let selection: ConformanceRun.Selection = changed ? .changed : all ? .all : .families(family)
                var passed = true
                try await output.answer({
                    let ran = try await ToolingService().runConformance(
                        host, selection: selection, record: record, device: device, in: here, reporter: BuildOptions.terminal)
                    passed = ran.passed
                    return ran
                }) { (ran: SuiteResult) in
                    ran.phases.map { "\($0.passed ? "passed" : "FAILED")  \($0.name)" }.joined(separator: "\n")
                }
                if !passed { throw ExitCode(ExitStatus.of(ToolingError(.toolFailed, "the run failed"))) }
            }
        }
    }
}
