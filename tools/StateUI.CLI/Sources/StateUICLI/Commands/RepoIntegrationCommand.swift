// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

extension RepoCommand {
    /// `stateui repo integration package | install --editor vscode`: the checkout's editor extension.
    struct Integration: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Packages the checkout's editor extension, or installs it in the editor.", subcommands: [Package.self, Install.self])

        /// `stateui repo integration package --editor vscode`.
        struct Package: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Packages the editor's extension from its sources into artifacts/<name>-<version>.vsix.")

            @Option(help: "The editor: vscode.")
            var editor: Editor

            @OptionGroup var output: OutputOptions

            func run() async throws {
                let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                try await output.answer({
                    try await ToolingService().packageIntegration(editor, in: here, reporter: BuildOptions.terminal)
                }) { (made: EditorExtension) in
                    "packaged \(made.extensionId) \(made.version) in \((try? FileURI.url(made.artifactUri).path) ?? made.artifactUri)"
                }
            }
        }

        /// `stateui repo integration install --editor vscode [--editor-path <path>]`.
        struct Install: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Packages the editor's extension, installs it over any other version with the editor's command line, and finds it listed at its version.")

            @Option(help: "The editor: vscode.")
            var editor: Editor

            @Option(help: "The editor's command line: code on the search path when left out.")
            var editorPath: String?

            @OptionGroup var output: OutputOptions

            func run() async throws {
                let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                guard let command = editorPath.map({ URL(fileURLWithPath: $0) }) ?? SearchPath().find("code") else {
                    throw ToolingError(.missingToolchain, "No code on the search path: name the editor's command line with --editor-path.")
                }
                try await output.answer({
                    let service = ToolingService()
                    let made = try await service.packageIntegration(editor, in: here, reporter: BuildOptions.terminal)
                    return try await service.installIntegration(
                        IntegrationInstallRequest(editorExtension: made, editorExecutableUri: FileURI.string(command)), reporter: BuildOptions.terminal)
                }) { (installed: EditorExtension) in
                    "installed \(installed.extensionId) \(installed.version): reload the editor's windows to run it"
                }
            }
        }
    }
}

extension Editor: ExpressibleByArgument {}
