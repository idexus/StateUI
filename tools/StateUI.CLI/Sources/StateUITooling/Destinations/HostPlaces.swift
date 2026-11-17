// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The hosts a machine builds and runs heads of, and where they run: the one list the server's information, the
/// destinations and the work asked of a guest read, so every client - an editor, a generated project, the terminal -
/// is told the same.
/// Design: docs/design/tooling/destinations.md#where-a-hosts-heads-run
enum HostPlaces {
    /// This machine's.
    static var here: [HostPlace] { of(system: Machine.current.system) }

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

    /// Where `host`'s heads run from this machine; nil where it builds none.
    static func place(of host: HostFamily?) -> HostPlace.Place? {
        here.first { $0.host == host }?.place
    }

    /// This machine, as the destination of a head that runs as its own program: its architecture, and the ones it runs
    /// emulated - x86_64 on an ARM64 Windows.
    static func machine(_ machine: Machine = .current) -> Destination {
        let own = Architecture(rawValue: machine.architecture)
        return Destination(
            id: "machine", udid: "machine", name: "This machine", kind: .machine, version: machine.system,
            architecture: own, emulated: machine.system == "windows" && own == .arm64 ? [.x86_64] : [])
    }
}
