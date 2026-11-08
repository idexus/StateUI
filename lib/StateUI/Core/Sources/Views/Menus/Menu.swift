// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A menu: a caption and the entries it opens - on the menu bar, or one level
/// down inside another menu.
///
///     .menuBar {
///         Menu("File") {
///             MenuItem("New").onClicked { create() }
///             Menu("Recent") {
///                 recent.map { file in
///                     MenuItem(file).onClicked { open(file) }
///                 }
///             }
///             MenuSeparator()
///             MenuItem("Close").onClicked { close() }
///         }
///         .joins(.file)
///     }
///
/// Not a view: a menu stands on the menu bar a view declares with `.menuBar`,
/// in a view's `.contextMenu`, or inside another menu.
public struct Menu: Element {
    /// The node this menu describes.
    public var node: Node

    /// A menu captioned `text`, holding whatever the closure lists.
    ///
    /// What goes inside is a `MenuItem`, a `MenuToggle`, a `Menu` or a
    /// `MenuSeparator`, with an `if` or an array of items among them.
    ///
    /// - Parameter text: the caption - "File", "Edit", "View" on the bar, or the
    ///   row that opens it inside another menu.
    /// - Parameter items: the entries, in the order they are written.
    public init(_ text: String, @MenuBuilder items: () -> MenuEntries) {
        node = Node(contract: MenuContract.self, children: items().nodes)
        node.write(TextElementContract.text, text)
    }

    /// Who this menu is among the others, so it stays matched to itself when
    /// the menus around it come and go; without one it is matched by position.
    /// On the menu bar a menu joins the one of an equal id declared around it.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        if let joined = node.identity?.value.base as? PlatformMenu {
            complain("A menu joining the platform's \(joined.menu) is who it is by that: `.id` cannot stand beside "
                + "`.joins`, and the join stands.")
            return copy
        }
        copy.node.identify(value)
        return copy
    }

    /// Joins the platform's own menu of that kind on the menu bar - its own
    /// entries stay, and this menu's stand after them as a section of their
    /// own - by this, never by its caption. It is who the menu is, so a menu
    /// joining takes no `.id`.
    ///
    ///     Menu("Plik") { … }.joins(.file)
    public func joins(_ menu: StandardMenu) -> Self {
        var copy = self
        copy.node.identify(PlatformMenu(menu: menu))
        return copy
    }

    /// Whether the menu opens at all.
    public func isEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.node.write(EnabledElementContract.isEnabled, value)
        return copy
    }
}

/// The identity of a menu joining the platform's: no value an application writes is one.
/// Design: docs/design/core/identity-and-diffing.md#menu-identities
struct PlatformMenu: Hashable, Sendable {
    let menu: StandardMenu
}
