// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One entry in a menu.
///
///     MenuItem("Save")
///         .icon("nav_media.png")
///         .onClicked { save() }
public struct MenuItem: Element, MenuItemElement {
    /// The node this entry describes.
    public var node: Node

    /// An entry captioned `text`. Give it an `.onClicked`: an entry that does
    /// nothing is one that looks broken.
    public init(_ text: String) {
        node = Node(contract: MenuItemContract.self)
        node.write(MenuItemElementContract.text, text)
    }

    /// Whether it stands checked: a mark beside it, for a setting choosing it
    /// turns on and off. One-way: the turn goes nowhere without `.onToggled`.
    public func isOn(_ value: Bool) -> Self {
        setValue(MenuItemContract.isOn, value)
    }

    /// Two-way: stands checked as the state holds, and choosing it turns the
    /// state over.
    ///
    ///     MenuItem("Show Ruler").isOn($showsRuler)
    ///
    /// The state is read where the menu is built, so a change builds that
    /// body again: a menu is walked from the tree, never a channel of its own.
    /// Design: docs/design/host/pages.md#a-checked-entry
    public func isOn(_ state: Binding<Bool>) -> Self {
        modified {
            $0.props[MenuItemContract.isOn.token] = .bool(state.wrappedValue)
            $0.addHandler(MenuItemContract.toggled.token) {
                if let turned = EventBuffer.current.value()?.bool { state.wrappedValue = turned }
            }
        }
    }

    /// Fires when the user chooses it checked or not, with the way it turned
    /// to. Runs after a binding's write, and before `.onClicked`.
    public func onToggled(_ handler: @escaping @MainActor (Bool) throws -> Void) -> Self {
        modified { $0.addHandler(MenuItemContract.toggled, handler) }
    }

    /// Who this entry is among the menu's others, so it stays matched to itself
    /// when the entries around it come and go; without one it is matched by
    /// position. On the menu bar an entry with the id of an entry in the menu
    /// declared around it stands in that entry's place.
    public func id(_ value: some Hashable) -> Self {
        modified { $0.identify(value) }
    }
}
