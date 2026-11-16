// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui project`: what a project holds.
struct ProjectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "project",
        abstract: "Reads a project of StateUI applications, or changes the StateUI they build with.",
        subcommands: [Describe.self, Library.self]
    )

    /// `stateui project describe`: the applications, their hosts and the StateUI they build with.
    struct Describe: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Shows a project's applications, the hosts each has a head for and the StateUI each builds with."
        )

        @Option(help: "The project, or a folder in it; the working directory when left out.")
        var project: String?

        @OptionGroup var output: OutputOptions

        func run() async throws {
            let folder = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)
            try await output.answer({ try await ToolingService().describeProject(containing: folder) }, text: Self.words)
        }

        static func words(_ project: Project) -> String {
            let root = (try? FileURI.url(project.rootUri).path) ?? project.rootUri
            let width = project.applications.map(\.id.count).max() ?? 0
            var lines = [root]
            for application in project.applications {
                let hosts = application.declaredHosts.map(\.rawValue).joined(separator: " ")
                lines.append("  \(application.id.padding(toLength: width, withPad: " ", startingAt: 0))  \(hosts)")
            }
            for library in project.libraries {
                let path = (try? FileURI.url(library.rootUri).path) ?? library.rootUri
                let state = [library.revision.map { String($0.prefix(9)) }, library.dirty == true ? "changed" : nil]
                    .compactMap { $0 }.joined(separator: ", ")
                lines.append("StateUI \(library.release ?? "?") at \(path)\(state.isEmpty ? "" : " (\(state))")")
            }
            return lines.joined(separator: "\n")
        }
    }

    /// `stateui project library`: another StateUI for the project - one application's checkout, or a workspace's.
    struct Library: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Makes a checkout - or, for a workspace, a release - the StateUI a project builds with.")

        @Option(help: "The project, or a folder in it; the working directory when left out.")
        var project: String?

        @OptionGroup var library: LibraryOptions
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let folder = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)
            try await output.answer({
                try await ToolingService().useLibrary(
                    in: folder, checkout: library.checkout.map { URL(fileURLWithPath: $0) }, release: library.release,
                    repository: library.repository)
            }, text: Self.words)
        }

        static func words(_ change: LibraryChange) -> String {
            let paths = change.changedUris.map { (try? FileURI.url($0).path) ?? $0 }
            return (["\((try? FileURI.url(change.projectUri).path) ?? change.projectUri), library \(change.library)"]
                + paths.map { "  \($0)" }).joined(separator: "\n")
        }
    }
}
