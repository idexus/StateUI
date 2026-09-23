// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The desktop menu bar: a page writes its menus into its session, and the
// platform puts them where it puts menus. A phone shows none of it.

/// A menu: a caption and the entries it opens - on the menu bar, or one level
/// down inside another menu.
///
///     page.menuBar = [
///         Menu("File") {
///             MenuItem("New").onClicked { create() }
///             Menu("Recent") {
///                 ForEach(recent) { file in
///                     MenuItem(file).onClicked { open(file) }
///                 }
///             }
///             MenuSeparator()
///             MenuItem("Close").onClicked { close() }
///         },
///     ]
///
/// Not a view: a menu belongs to a page, written into the page's session.
public struct Menu: Element {
    /// The node this menu describes.
    public var node: Node

    /// A menu captioned `text`, holding whatever the closure lists.
    ///
    /// What goes inside is a `MenuItem`, a `Menu` or a `MenuSeparator`, with an
    /// `if` or a `ForEach` among them.
    ///
    /// - Parameter text: the caption - "File", "Edit", "View" on the bar, or the
    ///   row that opens it inside another menu.
    /// - Parameter items: the entries, in the order they are written.
    public init(_ text: String, @MenuBuilder items: () -> [Element]) {
        node = Node(contract: MenuContract.self, children: items().map { $0.body })
        node.write(MenuContract.text, text)
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// Who this menu is among the page's others, so it stays matched to itself
    /// when the menus around it come and go; without one it is matched by
    /// position.
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
    /// position.
    public func id(_ value: some Hashable) -> Self {
        modified { $0.id = String(describing: value) }
    }
}

/// A line between entries, grouping the ones above it apart from the ones
/// below.
///
///     Menu("File") {
///         MenuItem("New").onClicked { create() }
///         MenuSeparator()
///         MenuItem("Close").onClicked { close() }
///     }
///
/// It has no caption and nothing to click; the platform draws whatever a
/// separator looks like there.
public struct MenuSeparator: Element {
    /// The node this separator describes.
    public var node: Node

    /// A line.
    public init() {
        node = Node(contract: MenuSeparatorContract.self)
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// Who this separator is, among the menu's others - worth giving one when
    /// entries come and go around it.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.id = String(describing: value)
        return copy
    }
}

/// Collects the entries of a menu written as consecutive statements.
///
///     Menu("View") {
///         MenuItem("Zoom in").onClicked { zoom(+1) }
///
///         if canReset {
///             MenuItem("Actual size").onClicked { zoom(0) }
///         }
///     }
///
/// An `if`, an `if/else` and a `ForEach` work in one, and a plain `for` does
/// not. An entry is matched by its `.id()` and otherwise by its position, so a
/// hand-written entry beside an `if` wants an id; `ForEach` gives its entries
/// their items' identities.
@resultBuilder
public enum MenuBuilder {
    /// A single entry written as a statement.
    public static func buildExpression(_ expression: Element) -> [Element] {
        [expression]
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [Element]) -> [Element] {
        expression
    }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ components: [Element]...) -> [Element] {
        components.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: [Element]?) -> [Element] {
        component ?? []
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: [Element]) -> [Element] {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: [Element]) -> [Element] {
        component
    }

    /// A `ForEach`'s entries, each identified by its item.
    public static func buildExpression(_ expression: ForEach) -> [Element] {
        expression.elements
    }
}
