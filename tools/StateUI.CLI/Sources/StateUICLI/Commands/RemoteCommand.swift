// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui remote`: the machines whose service this one is paired with.
struct RemoteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remote", abstract: "Pairs this machine with another's service, lists the machines paired or forgets one.",
        subcommands: [Add.self, List.self, Remove.self])

    /// `stateui remote add <name> <address:port> --code <code>`.
    struct Add: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Pairs with the service of another machine with the code it shows, and keeps it as <name>.")

        @Argument(help: "The machine's name here.")
        var name: String

        @Argument(help: "Where its service listens: an address and a port, 192.168.1.20:7979.")
        var place: String

        @Option(help: "The pairing code its service shows.")
        var code: String

        func run() async throws {
            do {
                let (address, port) = try ServiceCommand.place(place)
                let machine = try await RemoteMachines().pair(name: name, address: address, port: port, code: code)
                print("stateui: paired with \(machine.service) as \(machine.name)")
            } catch let error as ToolingError {
                try OutputFormat.text.write(error)
                throw ExitCode(ExitStatus.of(error))
            }
        }
    }

    /// `stateui remote list`.
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Lists the machines paired, with where their service listens.")

        func run() {
            let machines = RemoteMachines().list()
            print(machines.isEmpty ? "No machine is paired." : machines.map { "\($0.name) (\($0.service)) \($0.address):\($0.port)" }.joined(separator: "\n"))
        }
    }

    /// `stateui remote remove <name>`.
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Forgets a machine paired.")

        @Argument(help: "The machine's name here.")
        var name: String

        func run() throws {
            guard try RemoteMachines().remove(name) else {
                try OutputFormat.text.write(ToolingError(.notFound, "No machine named \(name) is paired."))
                throw ExitCode(ExitStatus.of(ToolingError(.notFound, "")))
            }
        }
    }
}
