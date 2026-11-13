// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import StateUITooling
import StateUIToolingProtocol

/// `stateui releases`: StateUI's published releases.
struct ReleasesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "releases",
        abstract: "Reads StateUI's published releases.",
        subcommands: [List.self]
    )

    /// `stateui releases list`: the releases a workspace can build with, newest first.
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Lists the releases a workspace can build with, newest first.")

        @Option(help: "The oldest release listed; the oldest the tool can build with when left out.")
        var minimum: String?

        @Option(help: "The repository read; StateUI's own when left out.")
        var repository: String?

        @OptionGroup var output: OutputOptions

        func run() async throws {
            try await output.answer({ try await ToolingService().listReleases(of: repository, from: minimum) }) {
                $0.releases.joined(separator: "\n")
            }
        }
    }
}
