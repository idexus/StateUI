// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

struct GuestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "guest", abstract: "Works on a guest of this Mac a GTK or WinUI head is built in.",
        subcommands: [Prepare.self])

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
}
