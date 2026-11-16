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
        abstract: "Makes a workspace, or changes the StateUI its applications build with.",
        subcommands: [Create.self, Library.self]
    )

    /// The library named on a command line: a checkout or a release.
    struct LibraryOptions: ParsableArguments {
        @Option(help: "A StateUI checkout to build with.")
        var checkout: String?

        @Option(help: "A StateUI release to build with, cloned into the workspace's StateUI/.")
        var release: String?

        @Option(help: "The repository a release is cloned from; StateUI's own when left out.")
        var repository: String?

        func validate() throws {
            guard (checkout == nil) != (release == nil) else {
                throw ValidationError("Name one library: --checkout or --release.")
            }
        }
    }

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

    /// `stateui workspace library`: the StateUI a workspace's applications build with from now on.
    struct Library: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Makes a checkout or a release the library of a workspace, rewriting its applications' manifests.")

        @Option(help: "A folder of the workspace; the working directory when left out.")
        var project: String?

        @OptionGroup var library: LibraryOptions
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let folder = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)
            try await output.answer({
                try await ToolingService().useLibrary(
                    in: folder, checkout: library.checkout.map { URL(fileURLWithPath: $0) }, release: library.release,
                    repository: library.repository)
            }, text: WorkspaceCommand.words)
        }
    }

    static func words(_ change: WorkspaceChange) -> String {
        let paths = change.changedUris.map { (try? FileURI.url($0).path) ?? $0 }
        return (["Workspace \((try? FileURI.url(change.workspaceUri).path) ?? change.workspaceUri), library \(change.library)"]
            + paths.map { "  \($0)" }).joined(separator: "\n")
    }
}
