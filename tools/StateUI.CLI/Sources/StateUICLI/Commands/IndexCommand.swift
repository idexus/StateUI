// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui index`: what an editor's language server indexes a host's code with, and its scratch folders taken away.
struct IndexCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "index", abstract: "What a language server indexes a host's code with, or its scratch folders taken away.",
        subcommands: [Describe.self, Clean.self])

    /// `stateui index describe [--host <host>]`.
    struct Describe: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Says the scratch folder, triple and SDK a host's code is indexed with - plain Swift where no host is named.")
        @Option(help: "The host; plain Swift when left out.")
        var host: HostFamily?
        @OptionGroup var output: OutputOptions

        func run() async throws {
            try await output.answer({ await ToolingService().describeIndex(of: host) }) { (context: IndexContext) in
                ([context.scratchPath] + [context.triple, context.sdk, context.swiftSDK].compactMap { $0 }
                    + (context.fallback.map { ["for this machine: \($0)"] } ?? [])).joined(separator: "\n")
            }
        }
    }

    /// `stateui index clean [--project <folder>]...`.
    struct Clean: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Takes every host's index scratch folder away from the folders named.")
        @Option(help: "A package's folder; this one when left out. One option a folder.")
        var project: [String] = []
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let folders = project.isEmpty ? [FileManager.default.currentDirectoryPath] : project
            try await output.answer({
                try ToolingService().cleanIndex(in: folders.map { FileURI.string(URL(fileURLWithPath: $0)) })
            }) { (cleaning: IndexCleaning) in
                cleaning.removedUris.isEmpty ? "No index here." : cleaning.removedUris.map { "Removed \((try? FileURI.url($0).path) ?? $0)" }.joined(separator: "\n")
            }
        }
    }
}
