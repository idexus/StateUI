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

    /// The node, as every element answers it.
    public var body: Node { node }

    /// Who this entry is among the menu's others, so it stays matched to itself
    /// when the entries around it come and go; without one it is matched by
    /// position. On the menu bar an entry with the id of an entry in the menu
    /// declared around it stands in that entry's place.
    public func id(_ value: some Hashable) -> Self {
        modified { $0.id = String(describing: value) }
    }
}
