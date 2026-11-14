// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a head runs: a real device paired with this machine, or a simulator.
public struct Destination: Codable, Equatable, Sendable {
    /// Whether it is a real device or a simulator.
    public enum Kind: String, Codable, Sendable {
        case device
        case simulator
    }

    /// How a tool names it: a device's identifier as `devicectl` gives it, a simulator's UDID.
    public var id: String
    /// Its hardware's UDID - the one a development profile provisions; a simulator's own.
    public var udid: String
    public var name: String
    public var kind: Kind
    /// Its system's version: `27.0`.
    public var version: String
    /// A simulator's: whether it is booted.
    public var booted: Bool
    /// A device's: how it is reached - `USB`, `Wi-Fi`.
    public var connection: String?

    /// Destination `name`, reached as `id`.
    public init(id: String, udid: String, name: String, kind: Kind, version: String, booted: Bool = false, connection: String? = nil) {
        self.id = id
        self.udid = udid
        self.name = name
        self.kind = kind
        self.version = version
        self.booted = booted
        self.connection = connection
    }
}
