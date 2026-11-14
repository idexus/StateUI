// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The iPhones and iPads a UIKit head runs on: the real ones paired with this Mac (`devicectl`) and the simulators
/// (`simctl`), each of an iOS a head installs on - Apple's floor or newer - and the one a run means.
/// Design: docs/design/tooling/destinations.md
public struct AppleDestinations: Sendable {
    /// A reader of this Mac's destinations.
    public init() {}

    /// The paired devices, then the simulators, the newest runtime first.
    public func list() async -> [Destination] {
        let listed = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: listed) }
        _ = await ToolOutput.standardOutput(.name("xcrun"), ["devicectl", "list", "devices", "--quiet", "--json-output", listed.path])
        let devices = (try? Data(contentsOf: listed)).map(Self.devices(fromDevicectl:)) ?? []
        let simulators = await ToolOutput.standardOutput(.name("xcrun"), ["simctl", "list", "devices", "available", "-j"])
            .map { Self.simulators(fromSimctl: Data($0.utf8)) } ?? []
        return devices + simulators
    }

    /// What `devicectl list devices --json-output` wrote: the real iPhones and iPads paired with this Mac, of an iOS
    /// a head installs on, in the order listed.
    public static func devices(fromDevicectl json: Data) -> [Destination] {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let listed = (root["result"] as? [String: Any])?["devices"] as? [[String: Any]]
        else { return [] }
        let transports = ["wired": "USB", "localNetwork": "Wi-Fi"]
        return listed.compactMap { device in
            let hardware = device["hardwareProperties"] as? [String: Any] ?? [:]
            let properties = device["deviceProperties"] as? [String: Any] ?? [:]
            let connection = device["connectionProperties"] as? [String: Any] ?? [:]
            guard hardware["reality"] as? String == "physical", hardware["platform"] as? String == "iOS",
                  connection["pairingState"] as? String == "paired",
                  let version = properties["osVersionNumber"] as? String, Versions.atLeast(version, Doctor.appleFloor),
                  let id = device["identifier"] as? String
            else { return nil }
            let transport = connection["transportType"] as? String ?? ""
            return Destination(
                id: id, udid: hardware["udid"] as? String ?? id, name: properties["name"] as? String ?? id, kind: .device,
                version: version, connection: transports[transport] ?? transport)
        }
    }

    /// What `simctl list devices available -j` printed: the iPhones and iPads of the iOS runtimes a head installs on,
    /// the newest runtime first, each runtime's in the order listed.
    public static func simulators(fromSimctl json: Data) -> [Destination] {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let runtimes = root["devices"] as? [String: [[String: Any]]]
        else { return [] }
        let versioned = runtimes.compactMap { runtime, devices -> (String, [[String: Any]])? in
            guard let match = runtime.firstMatch(of: /\.iOS-(\d+)-(\d+)$/) else { return nil }
            let version = "\(match.1).\(match.2)"
            return Versions.atLeast(version, Doctor.appleFloor) ? (version, devices) : nil
        }
        .sorted { Versions.compare($0.0, $1.0) > 0 }
        return versioned.flatMap { version, devices in
            devices.compactMap { device -> Destination? in
                guard let udid = device["udid"] as? String, let name = device["name"] as? String else { return nil }
                return Destination(id: udid, udid: udid, name: name, kind: .simulator, version: version,
                                   booted: device["state"] as? String == "Booted")
            }
        }
    }

    /// The destination `wanted` names among `listed` - a device by its identifier, UDID or name first, else a
    /// simulator by its UDID or name, the newest runtime's - or, named none, the simulator booted, else an iPhone.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` where nothing listed is the one named, or nothing is.
    public static func choose(_ wanted: String?, from listed: [Destination]) throws -> Destination {
        if let wanted, !wanted.isEmpty {
            let named = { (each: Destination) in [each.id, each.udid, each.name].contains(wanted) }
            if let found = listed.first(where: { $0.kind == .device && named($0) }) ?? listed.first(where: { $0.kind == .simulator && named($0) }) {
                return found
            }
            throw ToolingError(.invalidConfiguration, "No iPhone, iPad or simulator here is \(wanted); `stateui devices --host uikit` lists them.")
        }
        let simulators = listed.filter { $0.kind == .simulator }
        guard let chosen = simulators.first(where: \.booted) ?? simulators.first(where: { $0.name.hasPrefix("iPhone") }) else {
            throw ToolingError(.invalidConfiguration, "No simulator of iOS \(Doctor.appleFloor) or newer is installed; add one in Xcode's Devices and Simulators.")
        }
        return chosen
    }
}
