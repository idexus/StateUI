// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What was chosen for an application on this machine, out of git: the host a run builds for where none is named,
/// and each host's device - a simulator or device, an emulator, a browser.
/// Design: docs/design/tooling/projects.md#what-was-chosen
public struct ApplicationSettings: ToolFile, Equatable {
    public static let currentVersion = 1

    public var schemaVersion: Int
    /// The host chosen.
    public var host: HostFamily?
    /// The device chosen for each host, by the host's name: `"uikit": "iPhone 18 Pro"`.
    public var devices: [String: String]

    /// An application's choices: `host`, and `devices` by host.
    public init(host: HostFamily? = nil, devices: [String: String] = [:]) {
        schemaVersion = Self.currentVersion
        self.host = host
        self.devices = devices
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, host, devices }

    /// The settings `decoder` holds; no `devices` is none chosen.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try fields.decode(Int.self, forKey: .schemaVersion)
        host = try fields.decodeIfPresent(HostFamily.self, forKey: .host)
        devices = try fields.decodeIfPresent([String: String].self, forKey: .devices) ?? [:]
    }

    /// Writes the settings, leaving out `devices` where none is chosen.
    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(schemaVersion, forKey: .schemaVersion)
        try fields.encodeIfPresent(host, forKey: .host)
        if !devices.isEmpty { try fields.encode(devices, forKey: .devices) }
    }

    public var problem: String? {
        let unknown = devices.keys.filter { HostFamily(rawValue: $0) == nil }.sorted()
        return unknown.isEmpty ? nil : "it chooses a device for no host: \(unknown.joined(separator: ", "))."
    }

    /// The device chosen for `host`.
    public func device(for host: HostFamily) -> String? { devices[host.rawValue] }

    /// Where an application in `folder` keeps them: `.stateui/settings.json`.
    public static func file(in folder: URL) -> URL {
        folder.appendingPathComponent(".stateui").appendingPathComponent("settings.json")
    }

    /// What was chosen for the application in `folder`; nothing where no file stands.
    public static func read(in folder: URL) throws(ToolingError) -> ApplicationSettings {
        let file = file(in: folder)
        return FileManager.default.fileExists(atPath: file.path) ? try read(file) : ApplicationSettings()
    }
}
