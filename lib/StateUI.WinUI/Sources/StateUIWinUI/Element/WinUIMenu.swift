// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A menu as the relay takes it: its entries flat - an item, a separator, a submenu opening and closing - each with
/// its caption and whether it can be chosen, and what each item does, in the items' order.
/// Design: docs/design/platforms/winui/pages.md#menus
@MainActor
struct WinUIMenu {
    private(set) var kinds: [Int32] = []
    private(set) var titles: [String] = []
    private(set) var enabled: [Bool] = []
    private(set) var actions: [() -> Void] = []

    /// The entries `container` holds, in order; none for no container.
    init(_ container: WinUIElement?) {
        if let container { add(container.children) }
    }

    private mutating func add(_ entries: [WinUIElement]) {
        for entry in entries {
            switch entry.type {
            case .menuItem:
                append(0, entry.value(.text)?.string ?? "", entry.value(.isEnabled)?.bool ?? true)
                actions.append { [weak entry] in entry?.send(.clicked, []) }
            case .menuSeparator:
                append(1, "", true)
            case .menu:
                append(2, entry.value(.text)?.string ?? "", entry.value(.isEnabled)?.bool ?? true)
                add(entry.children)
                append(3, "", true)
            default:
                break
            }
        }
    }

    private mutating func append(_ kind: Int32, _ title: String, _ isEnabled: Bool) {
        kinds.append(kind)
        titles.append(title)
        enabled.append(isEnabled)
    }
}
