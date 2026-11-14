// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

extension RepoCommand {
    /// `stateui repo distribution package [--output <folder>]`: the tool's own distribution.
    struct Distribution: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Packages the stateui tool itself.", subcommands: [Package.self])

        /// `stateui repo distribution package`.
        struct Package: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Builds stateui for release and archives it for this system and architecture with its license and notices, its SHA-256 beside it, then reads the archive back: what it holds, the libraries it loads, and the program run with no Swift on the search path.")

            @Option(name: .customLong("output"), help: "The folder the archive is written in: the checkout's artifacts/stateui when left out.")
            var folder: String?

            @OptionGroup var output: OutputOptions

            func run() async throws {
                let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                var passed = true
                try await output.answer({
                    let ran = try await ToolingService().packageDistribution(
                        into: folder.map { URL(fileURLWithPath: $0) }, in: here, reporter: BuildOptions.terminal)
                    passed = ran.passed
                    return ran
                }) { (ran: SuiteResult) in
                    (ran.phases.map { "\($0.passed ? "passed" : "FAILED")  \($0.name)" }
                        + (ran.artifactUri.map { ["archive \((try? FileURI.url($0).path) ?? $0)"] } ?? [])).joined(separator: "\n")
                }
                if !passed { throw ExitCode(ExitStatus.of(ToolingError(.toolFailed, "the distribution does not hold"))) }
            }
        }
    }
}
