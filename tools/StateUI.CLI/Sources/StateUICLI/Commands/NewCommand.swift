// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui new`: an application made from a StateUI checkout's HelloWorld.
struct NewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Makes a new application from a StateUI checkout's HelloWorld."
    )

    @Argument(help: "The application's name: letters and digits, starting with a letter.")
    var name: String

    @Option(help: "What names it to every platform, such as pl.example.notes; com.example.<name> when left out.")
    var identifier: String?

    @Option(help: "The folder it is made in; the working directory when left out.")
    var directory: String?

    @Option(help: "The StateUI checkout it builds with; the one holding the folder, or beside it, when left out.")
    var checkout: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let parent = directory.map { URL(fileURLWithPath: $0) } ?? here
        let library = checkout.map { URL(fileURLWithPath: $0) }
        try await output.answer({ try await ToolingService().createApplication(name, identifier: identifier, in: parent, from: library) }) {
            creation in
            let made = (try? FileURI.url(creation.createdUris.first ?? "").path) ?? ""
            return "Created \(made)\n" + ProjectCommand.Describe.words(creation.project)
        }
    }
}
