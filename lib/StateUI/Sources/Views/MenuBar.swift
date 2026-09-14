// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The desktop menu bar. A page writes its menus into its session and each menu
// lists its entries, and the platform puts them where a desktop puts menus - at
// the top of the screen on a Mac, under the title bar on Windows. A phone has no
// menu bar and shows none of it.

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
/// Not a view: a menu has a caption and entries, no layout of its own, and it
/// belongs to a PAGE rather than sitting in one - written into the page's
/// session, and written again when what it lists moves.
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
        node = Node(
            type: .menu,
            props: [.text: .string(text)],
            children: items().map { $0.body })
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// Who this menu is, among the page's others - what keeps it matched to
    /// itself when the menus around it come and go. A menu with no id is
    /// matched by its POSITION in the list.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.id = String(describing: value)
        return copy
    }

    /// Whether the menu opens at all.
    public func isEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.node.props[.isEnabled] = .bool(value)
        return copy
    }
}

/// One entry in a menu.
///
///     MenuItem("Save")
///         .iconImageSource("nav_media.png")
///         .onClicked { save() }
public struct MenuItem: Element, MenuItemElement {
    /// The node this entry describes.
    public var node: Node

    /// An entry captioned `text`. Give it an `.onClicked`: an entry that does
    /// nothing is one that looks broken.
    public init(_ text: String) {
        node = Node(type: .menuItem, props: [.text: .string(text)])
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// Who this entry is, among the menu's others - what keeps it matched to
    /// itself when the entries around it come and go. An entry with no id is
    /// matched by its POSITION in the menu.
    public func id(_ value: some Hashable) -> Self {
        modified { $0.id = String(describing: value) }
    }

    // `text`, `iconImageSource`, `isDestructive`, `isEnabled` and `onClicked`
    // are shared with the toolbar item and the swipe action and live on
    // MenuItemElement, which this conforms to.
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
        node = Node(type: .menuSeparator)
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
/// Shaped like `ViewBuilder` and over the same `[Element]` - a menu's entries
/// ARE elements - so an `if`, an `if/else` and a `ForEach` all work in one, and
/// a plain `for` does not.
///
/// It collects without KEYING, and that is the one difference from a layout
/// that shows: an entry carries no note of which statement or which branch
/// produced it, so it is matched by the `.id()` it was given and by its
/// POSITION otherwise. An `if` whose entry comes and goes therefore re-matches
/// every entry below it against a different one. `ForEach` stamps each entry
/// with its item, so a list of them needs no ids; a hand-written entry standing
/// beside a conditional wants one.
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

    /// A loop's entries - `ForEach`, each identified by its item, which is
    /// how a menu lists recent files. A plain `for` does not compile in a
    /// menu for the reason it does not in a layout: a turn's number is the
    /// position, and the entries here are kept by identity.
    public static func buildExpression(_ expression: ForEach) -> [Element] {
        expression.elements
    }
}
