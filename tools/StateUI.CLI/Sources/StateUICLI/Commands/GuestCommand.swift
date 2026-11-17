// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

struct GuestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "guest", abstract: "Works on a guest of this Mac a GTK or WinUI head is built in.",
        subcommands: [Prepare.self, Pair.self])

    struct Prepare: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Lays this checkout's stateui in a guest: copied, built there and put in stateui-guest/bin.")

        @Option(help: "The guest, as `stateui devices --host gtk` or `--host winui` names it.")
        var device: String

        func run() async throws {
            let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let tool = try await ToolingService().prepareGuest(device, in: here, reporter: BuildOptions.terminal)
            print("Laid \(tool) in \(device).")
        }
    }

    /// `stateui guest pair --device <guest> [--port 7979]`.
    struct Pair: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Lays the service in a guest to start with its user's session, and pairs this Mac with it by its address.")

        @Option(help: "The guest, as `stateui devices --host gtk` or `--host winui` names it.")
        var device: String

        @Option(help: "The port its service listens on.")
        var port: UInt16 = 7979

        func run() async throws {
            let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            do {
                let machine = try await ToolingService().pairGuest(device, port: port, in: here, reporter: BuildOptions.terminal)
                print("stateui: paired with \(machine.service) as \(machine.name) at \(machine.address):\(machine.port)")
            } catch let error as ToolingError {
                try OutputFormat.text.write(error)
                throw ExitCode(ExitStatus.of(error))
            }
        }
    }
}
