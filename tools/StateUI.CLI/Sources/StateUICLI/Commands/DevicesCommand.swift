// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
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

    @OptionGroup var output: OutputOptions

    func run() async throws {
        try await output.answer({ try await ToolingService().listDestinations(of: host) }, text: Self.words)
    }

    /// A line a destination: its name, kind, system and state, then what names it.
    static func words(_ list: DestinationList) -> String {
        if list.destinations.isEmpty { return "No device or simulator for \(list.host.rawValue) here." }
        return list.destinations.map { each in
            let state = each.kind == .browser ? (each.booted ? "the system's own" : "")
                : each.kind == .device || each.kind == .guest ? each.connection ?? "" : each.booted ? "booted" : "not running"
            let facts = [each.kind.rawValue, each.version, each.architecture?.rawValue ?? "", state].filter { !$0.isEmpty }.joined(separator: ", ")
            return "\(each.name) (\(facts)) \(each.id)"
        }.joined(separator: "\n")
    }
}
