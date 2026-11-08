// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

/// The contracts whose members this process made, each by its name: what refuses a second contract of one name,
/// whose members would cross under the first's keys.
/// Design: docs/design/core/contracts.md#tokens
struct ContractNames {
    private var holders: [KeyName: (contract: ObjectIdentifier, described: String)] = [:]

    /// Takes `name` for `contract`: nil where it is free or `contract`'s already, else the contract holding it.
    mutating func take(_ name: KeyName, for contract: ObjectIdentifier, described: String) -> String? {
        if let holder = holders[name] { return holder.contract == contract ? nil : holder.described }

        holders[name] = (contract, described)
        return nil
    }

    /// Takes `owner`'s name, `name`: a second contract of one name stops the process. One body for every contract.
    /// Design: docs/design/platforms/web/runtime.md#the-modules-size
    static func claim(_ owner: any Contract.Type, named name: KeyName) {
        let described = String(reflecting: owner)
        let holder = taken.withLock { $0.take(name, for: ObjectIdentifier(owner), described: described) }
        precondition(holder == nil, "the contracts \(holder ?? "") and \(described) are both named `\(owner.name)`: "
            + "a member of one would cross under the other's keys")
    }

    /// Every contract name a member of this process was made under.
    private static let taken = Mutex(ContractNames())
}
