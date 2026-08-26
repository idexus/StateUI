// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: ToolbarItem.

/// A button in the page's navigation bar. MAUI: ToolbarItem.
///
///     struct NotesPage: ContentPage {
///         var title: String? { "Notes" }
///
///         var toolbarItems: [ToolbarItem] {
///             [
///                 ToolbarItem("Save")
///                     .onClicked { save() },
///
///                 ToolbarItem("Delete")
///                     .order(.secondary)
///                     .isDestructive(true)
///                     .onClicked { delete() },
///             ]
///         }
///     }
///
/// Not a view: MAUI's ToolbarItem is a MenuItem - a caption, a picture and
/// something to run - so it takes none of the modifiers a view has, and it
/// belongs to a PAGE rather than sitting in one.
public struct ToolbarItem: Element, MenuItemElement {
    /// The node this item describes.
    public var node: Node

    /// An item captioned `text`. Give it an `.onClicked`: an item that does
    /// nothing is one that looks broken.
    public init(_ text: String) {
        node = Node(type: .toolbarItem, props: [.text: .string(text)])
    }

    /// The node this item describes.
    public var body: Node { node }

    /// Who this item is, among the page's others - the same `.id()` a view
    /// takes, so one value means one thing wherever identity is given.
    ///
    /// An item inserted in the middle is then matched to itself rather than to
    /// whichever item now stands where it did.
    ///
    /// - Parameter value: distinct among the page's items, and the same value
    ///   across renders.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.id = String(describing: value)
        return copy
    }

    // `text`, `iconImageSource`, `isDestructive` and `isEnabled` are MenuItem's
    // and live on MenuItemElement, which this conforms to. What is left here is
    // what a TOOLBAR item alone has.

    /// Whether it sits on the bar itself or behind the overflow menu.
    /// MAUI: ToolbarItem.Order.
    public func order(_ value: ToolbarItemOrder) -> Self { setValue(.order, value.propValue) }

    /// What the platform sorts the page's items by, over the order they are
    /// written in. The number is passed to MAUI untouched, and which end of the
    /// range is drawn first is the platform's own business.
    /// MAUI: ToolbarItem.Priority.
    public func priority(_ value: Int) -> Self { setValue(.priority, .number(Double(value))) }

    /// What it does. MAUI: MenuItem.Clicked. A second `.onClicked` runs beside
    /// the first, like every typed event modifier.
    ///
    /// Written here rather than on `MenuItemElement` because a `SwipeItem` is
    /// answered by `Invoked` instead - see that protocol.
    public func onClicked(_ handler: @escaping EventHandler) -> Self {
        modified { $0.addHandler(.clicked, handler) }
    }
}
