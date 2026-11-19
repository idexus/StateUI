// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui workspace`: a folder of applications and the StateUI they build with, kept in its `stateui-workspace.json`.
struct WorkspaceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workspace",
        abstract: "Makes a workspace of applications and the StateUI they build with.",
        subcommands: [Create.self]
    )

    /// `stateui workspace create`: a workspace, its library, and maybe its first application.
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Makes a workspace building with a checkout or a release.")

        @Argument(help: "The workspace folder's name.")
        var name: String

        @Option(help: "The folder it is made in; the working directory when left out.")
        var directory: String?

        @Option(help: "The name of a first application made in it.")
        var application: String?

        @OptionGroup var library: LibraryOptions
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let parent = URL(fileURLWithPath: directory ?? FileManager.default.currentDirectoryPath)
            try await output.answer({
                try await ToolingService().createWorkspace(
                    name, in: parent, checkout: library.checkout.map { URL(fileURLWithPath: $0) }, release: library.release,
                    repository: library.repository, application: application)
            }, text: WorkspaceCommand.words)
        }
    }

    static func words(_ change: WorkspaceChange) -> String {
        let paths = change.changedUris.map { (try? FileURI.url($0).path) ?? $0 }
        return (["Workspace \((try? FileURI.url(change.workspaceUri).path) ?? change.workspaceUri), library \(change.library)"]
            + paths.map { "  \($0)" }).joined(separator: "\n")
    }
}
