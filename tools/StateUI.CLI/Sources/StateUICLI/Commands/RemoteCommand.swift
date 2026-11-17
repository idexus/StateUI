// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui remote`: the machines whose service a project is paired with.
struct RemoteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remote",
        abstract: "Pairs a project with another machine's service, lists the machines paired or forgets one - kept in the project's .stateui, out of git.",
        subcommands: [Add.self, List.self, Probe.self, Remove.self])

    /// The project whose paired machines a command means.
    struct ProjectOptions: ParsableArguments {
        @Option(help: "The project, or a folder in it; the working directory when left out.")
        var project: String?

        /// The machines its project is paired with.
        var remotes: RemoteMachines {
            RemoteMachines(project: URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath))
        }
    }

    /// `error` said on the terminal, ending the command by its kind.
    static func failed(_ error: ToolingError) throws -> Never {
        try OutputFormat.text.write(error)
        throw ExitCode(ExitStatus.of(error))
    }

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

        @OptionGroup var options: ProjectOptions

        func run() async throws {
            do {
                let (address, port) = try ServiceListener.place(place)
                let machine = try await options.remotes.pair(name: name, address: address, port: port, code: code)
                print("stateui: paired with \(machine.service) as \(machine.name)")
            } catch let error as ToolingError {
                try failed(error)
            }
        }
    }

    /// `stateui remote list`.
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Lists the machines paired, where their service listens, and whether it answers and admits this machine.")

        @OptionGroup var options: ProjectOptions

        func run() async throws {
            let machines: [RemoteMachine]
            do { machines = try options.remotes.list() } catch { try failed(error) }
            guard !machines.isEmpty else { return print("No machine is paired with this project.") }
            let answers = await withTaskGroup(of: (Int, ServiceProbe.Answer).self) { group in
                for (index, machine) in machines.enumerated() { group.addTask { (index, await ServiceProbe.check(machine)) } }
                return await group.reduce(into: [Int: ServiceProbe.Answer]()) { $0[$1.0] = $1.1 }
            }
            for (index, machine) in machines.enumerated() {
                print("\(machine.name) (\(machine.service)) \(machine.address):\(machine.port) - \(Self.words(answers[index]))")
            }
        }

        static func words(_ answer: ServiceProbe.Answer?) -> String {
            switch answer {
            case .admitted(let info):
                let hosts = info.hosts.map { "\($0.host.rawValue) (\($0.place.rawValue))" }.joined(separator: ", ")
                return "answers: \(info.machine.system) \(info.machine.architecture), stateui \(info.server.version); hosts \(hosts.isEmpty ? "none" : hosts)"
            case .notAdmitted(let why): return "answers, but admits this machine not - pair it again: \(why)"
            case .unreached(let why): return "does not answer: \(why)"
            case nil: return "not asked"
            }
        }
    }

    /// `stateui remote probe <address:port>`.
    struct Probe: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Says whether a stateui service answers at an address, and whether this machine is paired with it.")

        @Argument(help: "The address and the port: 10.211.55.4:7979.")
        var place: String

        @OptionGroup var options: ProjectOptions

        func run() async throws {
            do {
                let (address, port) = try ServiceListener.place(place)
                if let why = await ServiceProbe.probe(address, port: port) {
                    print("No stateui service answers at \(place): \(why)")
                    throw ExitCode(ExitStatus.of(ToolingError(.toolFailed, why)))
                }
                let paired = try options.remotes.list().first { $0.address == address && $0.port == port }
                guard let paired else {
                    return print("A stateui service answers at \(place); this project is not paired with it: `stateui remote add <name> \(place) --code <code>`.")
                }
                print("A stateui service answers at \(place), paired here as \(paired.name) - \(List.words(await ServiceProbe.check(paired)))")
            } catch let error as ToolingError {
                try failed(error)
            }
        }
    }

    /// `stateui remote remove <name>`.
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Forgets a machine paired.")

        @Argument(help: "The machine's name here.")
        var name: String

        @OptionGroup var options: ProjectOptions

        func run() throws {
            do {
                guard try options.remotes.remove(name) else { try failed(ToolingError(.notFound, "No machine named \(name) is paired with this project.")) }
            } catch let error as ToolingError {
                try failed(error)
            }
        }
    }
}
