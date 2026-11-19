// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A machine a project's manifest declares for everyone who works on it - `remotes` of its `stateui-workspace.json`,
/// else of its `stateui.json`: its name, where its service listens, and the identity it answers for. It holds no
/// secret: each user pairs with the machine once, the token kept out of git.
/// Design: docs/design/tooling/service.md#machines-a-project-declares
public struct DeclaredMachine: Codable, Equatable, Sendable {
    public var name: String
    /// Where its service listens: `192.168.1.20:7979`.
    public var address: String
    /// The identity its service answers for (`stateui service status` says it).
    public var identity: String

    /// The machine `name`, its service at `address`, answering for `identity`.
    public init(name: String, address: String, identity: String) {
        (self.name, self.address, self.identity) = (name, address, identity)
    }

    /// What the tool refuses of `machines`: a name empty or given twice, an address of no port, an identity not 64
    /// hexadecimal digits; nil where it takes them.
    static func problem(of machines: [DeclaredMachine]) -> String? {
        var seen: Set<String> = []
        for machine in machines {
            if machine.name.trimmingCharacters(in: .whitespaces).isEmpty { return "a machine of its remotes has no name." }
            if !seen.insert(machine.name).inserted { return "its remotes name \(machine.name) twice." }
            if (try? ServiceListener.place(machine.address)) == nil {
                return "its remote \(machine.name)'s address \"\(machine.address)\" is not an address and a port: 192.168.1.20:7979."
            }
            if machine.identity.count != 64 || !machine.identity.allSatisfy(\.isHexDigit) {
                return "its remote \(machine.name)'s identity is not 64 hexadecimal digits, as `stateui service status` says it."
            }
        }
        return nil
    }
}
