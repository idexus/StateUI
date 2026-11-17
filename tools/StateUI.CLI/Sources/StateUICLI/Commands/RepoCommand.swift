// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui repo`: the StateUI checkout's own work - its suites.
struct RepoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repo", abstract: "Works on a StateUI checkout itself.", subcommands: [Test.self, Conformance.self, API.self, Docs.self, Samples.self, WebSize.self, Integration.self, Distribution.self])

    /// `stateui repo test --suite host:<host>`, `stateui repo test --plan portable | native [--suite <id>]`.
    struct Test: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Runs a suite of the checkout's own - host:appkit, host:uikit, host:android, host:winui, host:gtk or host:web: the host's tests, every conformance verdict held, then its API records - or a plan of them in order: portable, the owner packages every machine runs; native, this machine's host suites.")

        @Option(help: "The suite: host:appkit, host:uikit, host:android, host:winui, host:gtk or host:web; with --plan, one of the plan's.")
        var suite: String?

        @Option(help: "portable (the library, the host layer, the conformance runner, application testing, the Gallery, HelloWorld, the tool) or native (this machine's host suites): each run apart, in order.")
        var plan: RepositoryPlan.Kind?

        @Option(help: "host:uikit's simulator, by name or UDID - the booted one, else an iPhone, when left out; host:android's device or emulator; host:gtk's or host:winui's guest, on a Mac.")
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

        func validate() throws {
            guard plan != nil || suite != nil else { throw ValidationError("Name a --suite, or a --plan.") }
        }

        func run() async throws {
            let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            var passed = true
            try await output.answer({
                let ran = if let plan {
                    try await ToolingService().runPlan(plan, only: suite, device: device, in: here, reporter: BuildOptions.terminal)
                } else {
                    try await ToolingService().testSuite(
                        suite ?? "", filter: filter, device: device, buildOnly: buildOnly, architecture: architecture,
                        artifact: artifact.map { URL(fileURLWithPath: $0) }, in: here, reporter: BuildOptions.terminal)
                }
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
                let selection: ConformanceSelection = changed ? .changed : all ? .all : .families(family)
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

    /// `stateui repo api check | record [--host <host>]`.
    struct API: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "api", abstract: "Holds the public API to lib/StateUI/exports/api, or records it.", subcommands: [Check.self, Record.self])

        struct Check: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Holds the library's public API to its records - with --host, the host's facade, backends and testing module, after the host's suite.")
            @OptionGroup var options: Options
            func run() async throws { try await options.answer(record: false) }
        }

        struct Record: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Writes the library's public API into its records - with --host, the host's facade, backends and testing module, after the host's suite.")
            @OptionGroup var options: Options
            func run() async throws { try await options.answer(record: true) }
        }

        struct Options: ParsableArguments {
            @Option(help: "The host whose modules' records are meant; the library's when left out.")
            var host: HostFamily?

            @Option(help: "UIKit's simulator or Android's device or emulator, by name or id.")
            var device: String?

            @OptionGroup var output: OutputOptions

            func answer(record: Bool) async throws {
                let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                var passed = true
                try await output.answer({
                    let ran = try await ToolingService().apiRecords(host: host, record: record, device: device, in: here, reporter: BuildOptions.terminal)
                    passed = ran.passed
                    return ran
                }) { (ran: SuiteResult) in
                    ran.phases.map { "\($0.passed ? "passed" : "FAILED")  \($0.name)" }.joined(separator: "\n")
                }
                if !passed { throw ExitCode(ExitStatus.of(ToolingError(.toolFailed, "the records do not hold"))) }
            }
        }
    }

    /// `stateui repo docs check | update`.
    struct Docs: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Holds the control dictionary and the platform contract to the marks, or renders them.", subcommands: [Check.self, Update.self])
        struct Check: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Holds docs/controls and docs/platform-contract.md to the marks.")
            @OptionGroup var output: OutputOptions
            func run() async throws { try await RepoCommand.handbook(samples: false, update: false, output) }
        }
        struct Update: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Renders docs/controls and docs/platform-contract.md from the marks.")
            @OptionGroup var output: OutputOptions
            func run() async throws { try await RepoCommand.handbook(samples: false, update: true, output) }
        }
    }

    /// `stateui repo samples check | update`.
    struct Samples: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Holds the Gallery's listings and the handbook's to the code they are cut from, or writes them.", subcommands: [Check.self, Update.self])
        struct Check: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Holds the listings to their code, every sample's review standing, every listing compiling.")
            @OptionGroup var output: OutputOptions
            func run() async throws { try await RepoCommand.handbook(samples: true, update: false, output) }
        }
        struct Update: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Writes the listings and records the review - only once each changed sample's notes and its listings' comments were read against the change.")
            @OptionGroup var output: OutputOptions
            func run() async throws { try await RepoCommand.handbook(samples: true, update: true, output) }
        }
    }

    /// Runs one of the handbook's own outputs' checks or updates, its phase said.
    static func handbook(samples: Bool, update: Bool, _ output: OutputOptions) async throws {
        let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var passed = true
        try await output.answer({
            let ran = try await ToolingService().handbook(samples: samples, update: update, in: here, reporter: BuildOptions.terminal)
            passed = ran.passed
            return ran
        }) { (ran: SuiteResult) in
            ran.phases.map { "\($0.passed ? "passed" : "FAILED")  \($0.name)" }.joined(separator: "\n")
        }
        if !passed { throw ExitCode(ExitStatus.of(ToolingError(.toolFailed, "they do not hold"))) }
    }

    /// `stateui repo web-size check [--application <name>]`.
    struct WebSize: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "web-size", abstract: "Holds each application's release Web module within its size budget.", subcommands: [Check.self])
        struct Check: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Builds each application's release Web module - or the one named - and holds it, gzipped, within its budget.")
            @Option(help: "The application, HelloWorld or Gallery; each when left out.")
            var application: String?
            @OptionGroup var output: OutputOptions
            func run() async throws {
                let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                var passed = true
                try await output.answer({
                    let ran = try await ToolingService().checkWebSizes(application: application, in: here, reporter: BuildOptions.terminal)
                    passed = ran.passed
                    return ran
                }) { (ran: SuiteResult) in
                    ran.phases.map { "\($0.passed ? "passed" : "FAILED")  \($0.name)" }.joined(separator: "\n")
                }
                if !passed { throw ExitCode(ExitStatus.of(ToolingError(.toolFailed, "a module is over its budget"))) }
            }
        }
    }
}
extension RepositoryPlan.Kind: ExpressibleByArgument {}
