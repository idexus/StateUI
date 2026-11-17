// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The virtual machines Parallels Desktop keeps on this Mac, as `prlctl list --all --info --json` describes them: a
/// Linux one is where a GTK head is built and run from here, a Windows one a WinUI head.
/// Design: docs/design/tooling/guests.md
public struct ParallelsGuests: Sendable {
    /// One guest as Parallels describes it.
    public struct Guest: Equatable, Sendable {
        /// The system a guest runs, as far as a host cares.
        public enum System: Equatable, Sendable {
            case linux
            case windows
            case other
        }

        /// Its identifier, which no rename changes.
        public var id: String
        public var name: String
        /// Parallels' word for its system: `ubuntu`, `win-11`.
        public var os: String
        public var system: System
        /// Parallels' word for its state: `running`, `suspended`, `stopped`.
        public var state: String
        public var architecture: Architecture?
        /// The Mac's folders it shares by name, enabled ones alone: a name and the Mac's path.
        public var shares: [String: String]
        /// Whether it shares every disk of the Mac.
        public var sharesAllDisks: Bool
        /// Whether Parallels Tools stand in it, which `prlctl exec` and the shared folders need.
        public var hasTools: Bool
    }

    private let path: SearchPath

    /// The guests `prlctl` on the search path of `environment` lists.
    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        path = SearchPath(environment: environment)
    }

    /// Parallels' command-line tool, where it stands: the Pro and Business editions have it.
    public var prlctl: URL? { path.find("prlctl") }

    /// Every guest, none where Parallels is not here.
    public func list() async -> [Guest] {
        guard let prlctl else { return [] }
        let text = await ToolOutput.standardOutput(.path(prlctl.path), ["list", "--all", "--info", "--json"]) ?? ""
        return Self.guests(fromJSON: Data(text.utf8))
    }

    /// The guests `json` - `prlctl list --all --info --json` - describes, in its order; none for what is no list.
    public static func guests(fromJSON json: Data) -> [Guest] {
        guard let list = try? JSONSerialization.jsonObject(with: json) as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            guard let id = entry["ID"] as? String, let name = entry["Name"] as? String else { return nil }
            let os = entry["OS"] as? String ?? ""
            let folders = entry["Host Shared Folders"] as? [String: Any] ?? [:]
            let sharing = folders["enabled"] as? Bool ?? false
            var shares: [String: String] = [:]
            for (share, value) in folders {
                guard sharing, let folder = value as? [String: Any], folder["enabled"] as? Bool == true,
                      let path = folder["path"] as? String else { continue }
                shares[share] = path
            }
            let cpu = (entry["Hardware"] as? [String: Any])?["cpu"] as? [String: Any]
            return Guest(
                id: id, name: name, os: os, system: Self.system(of: os), state: entry["State"] as? String ?? "",
                architecture: (cpu?["type"] as? String).map { $0 == "arm" ? .arm64 : .x86_64 }, shares: shares,
                sharesAllDisks: entry["Host defined sharing"] as? String == "All host disks",
                hasTools: (entry["GuestTools"] as? [String: Any])?["state"] as? String == "installed")
        }
    }

    /// The system of Parallels' word `os`.
    static func system(of os: String) -> Guest.System {
        if os.hasPrefix("win") { return .windows }
        let linux = ["ubuntu", "debian", "fedora", "linux", "opensuse", "redhat", "centos", "kali", "arch", "mint"]
        return linux.contains { os.hasPrefix($0) } ? .linux : .other
    }

    /// The system a head of `host` is built and run in, where a guest serves it.
    public static func system(for host: HostFamily) -> Guest.System? {
        switch host {
        case .gtk: .linux
        case .winui: .windows
        default: nil
        }
    }

    /// `guest` as a device a head is built for: named as Parallels names it, its system and state said.
    public static func destination(of guest: Guest) -> Destination {
        Destination(
            id: guest.name, udid: guest.id, name: guest.name, kind: .guest, version: guest.os,
            booted: guest.state == "running", connection: guest.state, architecture: guest.architecture)
    }
}
