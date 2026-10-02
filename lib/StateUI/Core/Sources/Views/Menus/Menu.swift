// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A menu: a caption and the entries it opens - on the menu bar, or one level
/// down inside another menu.
///
///     .menuBar {
///         Menu("File") {
///             MenuItem("New").onClicked { create() }
///             Menu("Recent") {
///                 ForEach(recent) { file in
///                     MenuItem(file).onClicked { open(file) }
///                 }
///             }
///             Divider()
///             MenuItem("Close").onClicked { close() }
///         }
///         .id(StandardMenu.file)
///     }
///
/// Not a view: a menu stands on the menu bar a view declares with `.menuBar`,
/// in a view's `.contextMenu`, or inside another menu.
public struct Menu: Element {
    /// The node this menu describes.
    public var node: Node

    /// A menu captioned `text`, holding whatever the closure lists.
    ///
    /// What goes inside is a `MenuItem`, a `Menu` or a `Divider`, with an
    /// `if` or a `ForEach` among them.
    ///
    /// - Parameter text: the caption - "File", "Edit", "View" on the bar, or the
    ///   row that opens it inside another menu.
    /// - Parameter items: the entries, in the order they are written.
    public init(_ text: String, @MenuBuilder items: () -> [Element]) {
        node = Node(contract: MenuContract.self, children: items().map { $0.node })
        node.write(MenuContract.text, text)
    }

    /// Who this menu is among the others, so it stays matched to itself when
    /// the menus around it come and go; without one it is matched by position.
    /// On the menu bar a menu joins the one of its id declared around it, and
    /// a `StandardMenu` joins the platform's own.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.id = String(describing: value)
        return copy
    }

    /// Whether the menu opens at all.
    public func isEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.node.write(MenuContract.isEnabled, value)
        return copy
    }
}
