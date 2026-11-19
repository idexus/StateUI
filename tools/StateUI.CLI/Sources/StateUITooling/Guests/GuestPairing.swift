// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A guest of this Mac paired with as any machine of the network is: its stateui's service laid to start with its
/// user's session, through `prlctl exec`, the code it shows read the same way, and the guest paired by the first of
/// its addresses the Mac reaches it at.
/// Design: docs/design/tooling/service.md#a-guest-paired
struct GuestPairing: Sendable {
    let guests: ParallelsGuests

    /// Pairs with the guest `device` names, its service listening on `port`, kept in `remotes` by the guest's name.
    func pair(
        _ device: String, port: UInt16, checkout: URL, remotes: RemoteMachines, reporter: BuildReporter
    ) async throws -> RemoteMachine {
        _ = try remotes.projectFile()
        guard let found = await guests.list().first(where: { $0.name == device || $0.id == device }) else {
            throw ToolingError(.invalidConfiguration, "No guest named \(device) stands here: `stateui devices` lists them.")
        }
        let readied = try await RemoteWork(guests: guests, remotes: []).readied(found, checkout: checkout, reporter: reporter)
        let (commands, tool) = (readied.commands, readied.places.tool)
        let environment = await commands.sessionEnvironment()
        func command(_ arguments: [String]) -> (String, [String]) {
            environment.isEmpty ? (tool, arguments) : ("env", environment + [tool] + arguments)
        }

        if found.system == .windows {
            // The guest is the Mac's own machine: its firewall is opened by Parallels Tools' account, with no prompt.
            reporter.progress("opening \(found.name)'s firewall to the service from its subnet")
            let script = ServiceAutostart.encoded(ServiceAutostart.firewallScript(program: tool, port: port))
            let opened = await commands.asSystem(#"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"#, ["-NoProfile", "-EncodedCommand", script])
            guard opened.status == 0 else {
                throw ToolingError(.toolFailed, "\(found.name)'s firewall was not opened to the service:\n\(opened.output)")
            }
        }
        reporter.progress("laying the service in \(found.name)")
        let install = command(["service", "install", "--listen", "0.0.0.0:\(port)"])
        let installed = await commands.status(install.0, install.1, timeout: .seconds(120))
        guard installed.status == 0 else {
            throw ToolingError(.toolFailed, "The service was not laid in \(found.name):\n\(installed.output)")
        }
        let asked = command(["service", "status", "--format", "json"])
        let said = await commands.run(asked.0, asked.1).output
        guard let start = said.firstIndex(of: "{"),
              let state = try? ToolingJSON.decoder().decode(Envelope<ServiceState>.self, from: Data(said[start...].utf8)).result else {
            throw ToolingError(.toolFailed, "\(found.name)'s service said no pairing code:\n\(said)")
        }

        let addresses = (await guests.list().first { $0.id == found.id } ?? found).addresses
        guard let address = addresses.first(where: { Self.answers($0, port: state.port) }) else {
            throw ToolingError(.toolFailed, "\(found.name)'s service answers at none of \(addresses.joined(separator: ", ")) on port \(state.port).")
        }
        reporter.progress("pairing with \(found.name) at \(address):\(state.port)")
        return try await remotes.pair(name: found.name, address: address, port: state.port, code: state.code)
    }

    /// Whether a service answers at `address` on `port`.
    private static func answers(_ address: String, port: UInt16) -> Bool {
        guard let socket = try? StreamSocket.connect(to: address, port: port) else { return false }
        socket.close()
        return true
    }
}
