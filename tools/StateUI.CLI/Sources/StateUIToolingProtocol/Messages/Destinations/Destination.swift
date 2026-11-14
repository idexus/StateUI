// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a head runs: a real device attached to or paired with this machine, a simulator, an emulator, or a
/// browser a Web head's page opens in.
public struct Destination: Codable, Equatable, Sendable {
    /// Whether it is a real device, an iOS simulator, an Android emulator or a browser.
    public enum Kind: String, Codable, Sendable {
        case device
        case simulator
        case emulator
        case browser
    }

    /// How a tool names it: a device's identifier as `devicectl` gives it, a simulator's UDID, an Android device's
    /// serial, an emulator's serial while it runs and its virtual device's name while it does not.
    public var id: String
    /// Its hardware's UDID - the one a development profile provisions; a simulator's own; an Android device's serial.
    public var udid: String
    public var name: String
    public var kind: Kind
    /// Its system's version: `27.0`, `14`; empty where it is not running to say it.
    public var version: String
    /// A simulator's or an emulator's: whether it is running; a browser's: whether it is the system's own.
    public var booted: Bool
    /// A device's: how it is reached - `USB`, `Wi-Fi`.
    public var connection: String?
    /// The architecture a build for it targets, where the platform says it: an Android device's ABI.
    public var architecture: Architecture?

    /// Destination `name`, reached as `id`.
    public init(
        id: String, udid: String, name: String, kind: Kind, version: String, booted: Bool = false, connection: String? = nil,
        architecture: Architecture? = nil
    ) {
        self.id = id
        self.udid = udid
        self.name = name
        self.kind = kind
        self.version = version
        self.booted = booted
        self.connection = connection
        self.architecture = architecture
    }
}
