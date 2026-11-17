// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol
import Synchronization

/// `stateui service`: the tool's service, which another machine's tool - or this one's - reaches over TCP with the
/// protocol an editor speaks, once paired with the code it shows; run here, or laid to start with the desktop session.
struct ServiceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "service",
        abstract: "Serves the tool's protocol over TCP, as another machine's tool reaches it.",
        subcommands: [Run.self, Install.self, Uninstall.self, Status.self], defaultSubcommand: Run.self)

    /// `stateui service [run] --listen <address:port>`.
    struct Run: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Serves until stopped, saying its pairing codes as they come.")

        @Option(help: "Where it listens: an address and a port, 0.0.0.0:7979, 127.0.0.1:7979 or [::1]:7979; port 0 takes a free one.")
        var listen: String

        func run() async throws {
            do throws(ToolingError) {
                let (address, port) = try ServiceListener.place(listen)
                let bound = Mutex<UInt16?>(nil)
                let pairing = ServicePairing(said: { code in
                    FileHandle.standardOutput.write(Data("stateui: pairing code \(code), good for ten minutes and one machine\n".utf8))
                    if let port = bound.withLock({ $0 }) { ServiceCommand.keep(address, port, code: code) }
                })
                let listener = try ServiceListener.open(on: address, port: port, pairing: pairing)
                bound.withLock { $0 = listener.port }
                ServiceCommand.keep(address, listener.port, code: pairing.code, until: pairing.codeUntil)
                defer { try? FileManager.default.removeItem(at: ServiceState.file) }
                let place = "\(address.contains(":") ? "[\(address)]" : address):\(listener.port)"
                FileHandle.standardOutput.write(Data("stateui: serving on \(place) - pair another machine with `stateui remote add <name> <address>:\(listener.port) --code <code>`\n".utf8))
                await listener.serve()
            } catch {
                try OutputFormat.text.write(error)
                throw ExitCode(ExitStatus.of(error))
            }
        }
    }

    /// `stateui service install --listen <address:port>`.
    struct Install: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Lays the service to start with this user's desktop session, and starts it now.")

        @Option(help: "Where it listens: an address and a port, 0.0.0.0:7979.")
        var listen: String

        func run() async throws {
            do {
                _ = try ServiceListener.place(listen)
                guard let program = Bundle.main.executableURL else { throw ToolingError(.internalError, "This program's path is not known.") }
                try await ServiceAutostart().install(program: program, listen: listen)
                for _ in 0..<40 where ServiceState.running() == nil { try await Task.sleep(for: .milliseconds(250)) }
                print(Status.words(ServiceState.running()))
            } catch let error as ToolingError {
                try OutputFormat.text.write(error)
                throw ExitCode(ExitStatus.of(error))
            }
        }
    }

    /// `stateui service uninstall`.
    struct Uninstall: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Stops the service laid to start with the desktop session, and takes it away.")

        func run() async throws {
            let laid = try await ServiceAutostart().uninstall()
            try? FileManager.default.removeItem(at: ServiceState.file)
            print(laid ? "stateui: the service no longer starts with the session." : "stateui: no service was laid to start.")
        }
    }

    /// `stateui service status`.
    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Says where this machine's service listens and the pairing code it shows now.")

        @OptionGroup var output: OutputOptions

        func run() throws {
            guard let state = ServiceState.running() else {
                let none = ToolingError(.notFound, "No service runs here.")
                try output.format.write(none)
                throw ExitCode(ExitStatus.of(none))
            }
            try output.format.write(state, text: Self.words)
        }

        static func words(_ state: ServiceState) -> String {
            words(Optional(state))
        }

        static func words(_ state: ServiceState?) -> String {
            guard let state else { return "No service runs here." }
            let until = state.codeUntil.formatted(date: .omitted, time: .shortened)
            return "stateui: serving on \(state.address):\(state.port); pairing code \(state.code), good until \(until) and for one machine"
        }
    }

    /// Writes what the service says of itself: where it listens, and the code it shows - new now where no end is said.
    static func keep(_ address: String, _ port: UInt16, code: String, until: Date = Date().addingTimeInterval(600)) {
        try? ServiceState(address: address, port: port, code: code, codeUntil: until).write()
    }

}
