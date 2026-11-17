// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui devices --host uikit`: where a host's heads can run on this machine.
struct DevicesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devices",
        abstract: "Lists the devices, simulators, emulators and browsers a host's heads run on here: --host uikit, android or web."
    )

    @Option(help: "The host whose devices to list: uikit, android or web - and on a Mac gtk and winui, its virtual machines.")
    var host: HostFamily

    @Option(help: "The project, or a folder in it, whose paired machines are listed too; the working directory when left out.")
    var project: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let folder = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)
        try await output.answer({ try await ToolingService().listDestinations(of: host, in: folder) }, text: Self.words)
    }

    /// A line a destination: its name, kind, system and state, then what names it.
    static func words(_ list: DestinationList) -> String {
        if list.destinations.isEmpty { return "No device or simulator for \(list.host.rawValue) here." }
        return list.destinations.map { each in
            let state = switch each.kind {
            case .machine: ""
            case .browser: each.booted ? "the system's own" : ""
            case .device, .guest, .remote: each.connection ?? ""
            case .simulator, .emulator: each.booted ? "booted" : "not running"
            }
            let facts = [each.kind.rawValue, each.version, each.architecture?.rawValue ?? "", state].filter { !$0.isEmpty }.joined(separator: ", ")
            return "\(each.name) (\(facts)) \(each.id)"
        }.joined(separator: "\n")
    }
}
