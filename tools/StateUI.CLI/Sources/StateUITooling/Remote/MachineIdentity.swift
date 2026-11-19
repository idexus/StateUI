// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The tool's own identity on this machine for its user: random, made once in the user's state folder and kept, so
/// another machine knows this one by it whatever its name or address - the folder this machine's work stands in there.
/// Design: docs/design/tooling/service.md#a-machines-identity
public struct MachineIdentity: ToolFile, Equatable {
    public static let currentVersion = 1

    public var schemaVersion: Int
    /// 32 random bytes, as hexadecimal.
    public var id: String

    init(id: String) {
        schemaVersion = Self.currentVersion
        self.id = id
    }

    public var problem: String? {
        id.count == 64 && id.allSatisfy(\.isHexDigit) ? nil : "its id is not 64 hexadecimal digits."
    }

    /// Its first twelve digits: the name of the folder this machine's work stands in on another.
    public var short: String { String(id.prefix(12)) }

    /// The identity kept in `folder`, made there the first time - once, however many processes ask at once.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a file the tool does not read, `TOOL_FAILED` where none
    ///   can be written.
    public static func current(in folder: URL = BuildPermit.userFolder) throws(ToolingError) -> MachineIdentity {
        let file = folder.appendingPathComponent("identity.json")
        if !FileManager.default.fileExists(atPath: file.path) {
            let made = MachineIdentity(id: ServicePairing.randomHex(32))
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let data = try ToolingJSON.encoder(pretty: true).encode(made) + Data("\n".utf8)
                try data.write(to: file, options: .withoutOverwriting)
            } catch where FileManager.default.fileExists(atPath: file.path) {
                // Another process made it first: its identity is the one.
            } catch {
                throw ToolingError(.toolFailed, "This machine's identity was not written to \(file.path): \(error).")
            }
        }
        return try read(file)
    }
}
