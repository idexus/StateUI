// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: MenuBarItem, MenuFlyoutItem, MenuFlyoutSubItem, MenuFlyoutSeparator.
//
// The desktop menu bar. A page declares its menus and each menu its entries, and
// the platform puts them where a desktop puts menus - at the top of the screen on
// a Mac, under the title bar on Windows. A phone has no menu bar and shows none
// of it, which is what MAUI does too.

/// One menu on the menu bar. MAUI: MenuBarItem.
///
///     var menuBarItems: [MenuBarItem] {
///         [
///             MenuBarItem("File") {
///                 MenuFlyoutItem("New").onClicked { create() }
///                 MenuFlyoutSeparator()
///                 MenuFlyoutItem("Close").onClicked { close() }
///             },
///         ]
///     }
///
/// Not a view: a menu has a caption and entries, no layout of its own, and it
/// belongs to a PAGE rather than sitting in one.
public struct MenuBarItem: Element {
    /// The node this menu describes.
    public var node: Node

    /// A menu captioned `text`, holding whatever the closure lists.
    ///
    /// What goes inside is a `MenuFlyoutItem`, a `MenuFlyoutSubItem` or a
    /// `MenuFlyoutSeparator`, with an `if` or a `ForEach` among them.
    ///
    /// - Parameter text: the caption on the bar - "File", "Edit", "View".
    /// - Parameter items: the entries, in the order they are written.
    public init(_ text: String, @MenuBuilder items: () -> [Element]) {
        node = Node(
            type: .menuBarItem,
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

    /// Whether the menu opens at all. MAUI: MenuBarItem.IsEnabled.
    public func isEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.node.props[.isEnabled] = .bool(value)
        return copy
    }
}

/// One entry in a menu. MAUI: MenuFlyoutItem.
///
///     MenuFlyoutItem("Save")
///         .iconImageSource("nav_media.png")
///         .onClicked { save() }
public struct MenuFlyoutItem: Element, MenuItemElement {
    /// The node this entry describes.
    public var node: Node

    /// An entry captioned `text`. Give it an `.onClicked`: an entry that does
    /// nothing is one that looks broken.
    public init(_ text: String) {
        node = Node(type: .menuFlyoutItem, props: [.text: .string(text)])
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// Who this entry is, among the menu's others - what keeps it matched to
    /// itself when the entries around it come and go. An entry with no id is
    /// matched by its POSITION in the menu.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.id = String(describing: value)
        return copy
    }

    // `text`, `iconImageSource`, `isDestructive` and `isEnabled` are MenuItem's
    // and live on MenuItemElement, which this conforms to.

    /// What it does. MAUI: MenuItem.Clicked. A second `.onClicked` runs beside
    /// the first, like every typed event modifier.
    ///
    /// Written here rather than on `MenuItemElement` because a `SwipeItem` is
    /// answered by `Invoked` instead - see that protocol.
    public func onClicked(_ handler: @escaping EventHandler) -> Self {
        modified { $0.addHandler(.clicked, handler) }
    }
}

/// A menu inside a menu. MAUI: MenuFlyoutSubItem.
///
///     MenuFlyoutSubItem("Recent") {
///         ForEach(recent) { file in
///             MenuFlyoutItem(file).onClicked { open(file) }
///         }
///     }
public struct MenuFlyoutSubItem: Element {
    /// The node this submenu describes.
    public var node: Node

    /// A submenu captioned `text`, holding whatever the closure lists.
    ///
    /// The same entries a `MenuBarItem` holds, one level in - a submenu may
    /// hold a submenu.
    ///
    /// - Parameter text: the caption of the row that opens it.
    /// - Parameter items: the entries, in the order they are written.
    public init(_ text: String, @MenuBuilder items: () -> [Element]) {
        node = Node(
            type: .menuFlyoutSubItem,
            props: [.text: .string(text)],
            children: items().map { $0.body })
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// Who this submenu is, among the menu's others - what keeps it matched to
    /// itself when the entries around it come and go. One with no id is matched
    /// by its POSITION in the menu.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.id = String(describing: value)
        return copy
    }

    /// Whether it opens at all. MAUI: MenuItem.IsEnabled.
    public func isEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.node.props[.isEnabled] = .bool(value)
        return copy
    }
}

/// A line between entries, grouping the ones above it apart from the ones
/// below. MAUI: MenuFlyoutSeparator.
///
///     MenuBarItem("File") {
///         MenuFlyoutItem("New").onClicked { create() }
///         MenuFlyoutSeparator()
///         MenuFlyoutItem("Close").onClicked { close() }
///     }
///
/// It has no caption and nothing to click; the platform draws whatever a
/// separator looks like there.
public struct MenuFlyoutSeparator: Element {
    /// The node this separator describes.
    public var node: Node

    /// A line.
    public init() {
        node = Node(type: .menuFlyoutSeparator)
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
///     MenuBarItem("View") {
///         MenuFlyoutItem("Zoom in").onClicked { zoom(+1) }
///
///         if canReset {
///             MenuFlyoutItem("Actual size").onClicked { zoom(0) }
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
