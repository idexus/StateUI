// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling

/// `stateui`, StateUI's developer tool.
@main
struct StateUICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stateui",
        abstract: "StateUI's developer tool.",
        version: Release.version,
        subcommands: [
            BuildCommand.self, DevicesCommand.self, DoctorCommand.self, InstallCommand.self, NewCommand.self, PackageCommand.self, ProjectCommand.self,
            ReleasesCommand.self, RepoCommand.self, RunCommand.self, ServeCommand.self, VersionCommand.self, WorkspaceCommand.self,
        ]
    )

    /// A command line naming no command: the help, on standard error, and status 2.
    func run() throws {
        FileHandle.standardError.write(Data((Self.helpMessage() + "\n").utf8))
        throw ExitCode(ExitStatus.invalidCommand)
    }

    /// Runs the command the arguments name; arguments a command does not take end with status 2.
    static func main() async {
        do {
            let command = try parseAsRoot()
            try await Interruption.run {
                if var command = command as? AsyncParsableCommand {
                    try await command.run()
                } else {
                    var command = command
                    try command.run()
                }
            }
        } catch {
            guard exitCode(for: error) == .validationFailure else { exit(withError: error) }
            FileHandle.standardError.write(Data((fullMessage(for: error) + "\n").utf8))
            Foundation.exit(ExitStatus.invalidCommand)
        }
    }
}
