// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import StateUITooling

/// `stateui version`: the tool's release, the API versions it speaks, the machine it runs on and the hosts it builds
/// there, each with where its heads run.
struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Shows the tool's release, the API versions it speaks, the machine it runs on and the hosts it builds there."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        let info = ToolingService().serverInfo()
        try output.format.write(info) { info in
            let versions = info.apiVersions.map(\.newest).joined(separator: ", ")
            let hosts = info.hosts.map { "\($0.host.rawValue) (\($0.place.rawValue))" }.joined(separator: ", ")
            return "stateui \(info.server.version), API \(versions), \(info.machine.system) \(info.machine.architecture)\n"
                + "hosts: \(hosts.isEmpty ? "none" : hosts)"
        }
    }
}
