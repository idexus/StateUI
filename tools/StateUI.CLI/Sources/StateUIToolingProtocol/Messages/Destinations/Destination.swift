// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a head runs: this machine itself, a real device attached to or paired with it, a simulator, an emulator, a
/// browser a Web head's page opens in, or a virtual machine of it.
public struct Destination: Codable, Equatable, Sendable {
    /// Whether it is this machine, a real device, an iOS simulator, an Android emulator, a browser or a virtual machine
    /// of this one.
    public enum Kind: String, Codable, Sendable {
        /// The machine the tool runs on, where an AppKit, GTK or WinUI head runs as the machine's own program.
        case machine
        case device
        case simulator
        case emulator
        case browser
        /// A virtual machine of this Mac - a Parallels guest - which a GTK or WinUI head is built and run in.
        case guest
        /// A machine of the network paired with this one, whose service builds and runs the head.
        case remote
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
    /// A device's: how it is reached - `USB`, `Wi-Fi`; a guest's: its state - `running`, `suspended`, `stopped`.
    public var connection: String?
    /// The architecture a build for it targets, where the platform says it: an Android device's ABI.
    public var architecture: Architecture?
    /// The architectures it runs emulated beside its own, which a head can be built for too: x86_64 on an ARM64
    /// Windows.
    public var emulated: [Architecture]
    /// Whether a debugger reaches an application run there: false in a guest, and in a browser not of Chromium's,
    /// whose pages no debugger follows.
    public var debugger: Bool
    /// A browser's program, as a file URI: what a debugger starts on a page.
    public var programUri: String?

    /// Destination `name`, reached as `id`.
    public init(
        id: String, udid: String, name: String, kind: Kind, version: String, booted: Bool = false, connection: String? = nil,
        architecture: Architecture? = nil, emulated: [Architecture] = [], debugger: Bool = true, programUri: String? = nil
    ) {
        self.id = id
        self.udid = udid
        self.name = name
        self.kind = kind
        self.version = version
        self.booted = booted
        self.connection = connection
        self.architecture = architecture
        self.emulated = emulated
        self.debugger = debugger
        self.programUri = programUri
    }
}
