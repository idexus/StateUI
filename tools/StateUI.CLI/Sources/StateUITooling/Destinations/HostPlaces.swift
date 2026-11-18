// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The hosts a machine builds and runs heads of, and where they run: the one list the server's information, the
/// destinations and the work asked of a guest read, so every client - an editor, a generated project, the terminal -
/// is told the same.
/// Design: docs/design/tooling/destinations.md#where-a-hosts-heads-run
enum HostPlaces {
    /// This machine's own.
    static var here: [HostPlace] { of(system: Machine.current.system) }

    /// This machine's own, and beside them the hosts whose heads run on a machine of `remotes` - as its own programs,
    /// on its devices or in its browsers - each at `remote`, in the matrix's order.
    static func available(remotes: [RemoteMachine]) -> [HostPlace] {
        let own = here
        let elsewhere = Set(remotes.flatMap { $0.machineHosts + $0.deviceHosts }).subtracting(own.map(\.host))
        return (own + elsewhere.map { HostPlace(host: $0, place: .remote) }).sorted { $0.host < $1.host }
    }

    /// A machine's of `system` - `macos`, `linux`, `windows` - in the matrix's order.
    static func of(system: String) -> [HostPlace] {
        switch system {
        case "macos":
            [HostPlace(host: .appkit, place: .machine), HostPlace(host: .uikit, place: .device),
             HostPlace(host: .android, place: .device), HostPlace(host: .winui, place: .guest),
             HostPlace(host: .gtk, place: .guest), HostPlace(host: .web, place: .browser)]
        case "linux":
            [HostPlace(host: .gtk, place: .machine), HostPlace(host: .web, place: .browser)]
        case "windows":
            [HostPlace(host: .winui, place: .machine)]
        default:
            []
        }
    }

    /// Where `host`'s heads run from this machine by its own means; nil where it builds none.
    static func place(of host: HostFamily?) -> HostPlace.Place? {
        here.first { $0.host == host }?.place
    }

    /// The folder another machine's projects are copied into for work here, as this machine's system writes a path.
    static var workFolder: String {
        FileURI.shown(FileURI.string(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("stateui-guest")))
    }

    /// This machine, as the destination of a head that runs as its own program: its architecture, and the ones it runs
    /// emulated - x86_64 on an ARM64 Windows.
    static func machine(_ machine: Machine = .current) -> Destination {
        let own = Architecture(rawValue: machine.architecture)
        return Destination(
            id: "machine", udid: "machine", name: "This machine", kind: .machine, version: machine.system,
            architecture: own, emulated: emulated(on: machine))
    }

    /// A machine paired, as the destination of the heads that run there as its own programs: its system and
    /// architecture as its service said them, and where it listens.
    static func remote(_ remote: RemoteMachine) -> Destination {
        Destination(
            id: remote.name, udid: "", name: remote.name, kind: .remote, version: remote.machine?.system ?? "",
            connection: "\(remote.address):\(remote.port)", architecture: remote.machine.flatMap { Architecture(rawValue: $0.architecture) },
            emulated: remote.machine.map(emulated(on:)) ?? [], debugger: false)
    }

    /// The architectures `machine` runs emulated beside its own: x86_64 on an ARM64 Windows.
    private static func emulated(on machine: Machine) -> [Architecture] {
        machine.system == "windows" && Architecture(rawValue: machine.architecture) == .arm64 ? [.x86_64] : []
    }
}
