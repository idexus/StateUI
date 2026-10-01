// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// How a driver says the bar it reads (`HostDriver.bar(of:)`), the same for every host: the leading groups, "|", the
/// trailing groups, "|", the overflow - a group its actions in brackets, groups and actions apart by a space.
@_spi(Host) @MainActor public enum BarWords {
    /// `leading`, `trailing` and `overflow` said: `"[filter]|[save add] [home]|more"`.
    public static func said(leading: [[String]], trailing: [[String]], overflow: [String]) -> String {
        let groups = { (groups: [[String]]) in groups.map { "[" + $0.joined(separator: " ") + "]" }.joined(separator: " ") }
        return groups(leading) + "|" + groups(trailing) + "|" + overflow.joined(separator: " ")
    }

    /// An action as the bar says it: its id, else its words - "!" before one that cannot be chosen.
    public static func word(_ element: MountedElement, enabled: Bool) -> String {
        let name: String
        if case .manual(let id) = element.id { name = id } else { name = element.value(.text)?.string ?? "" }
        return enabled ? name : "!" + name
    }
}
