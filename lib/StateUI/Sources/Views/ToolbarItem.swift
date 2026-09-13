// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An action in the page's native navigation or toolbar surface.
///
///     struct NotesPage: ContentPage {
///         @Environment private var page: PageSession
///
///         var content: any View {
///             VStack { … }
///                 .onCreated {
///                     page.title = "Notes"
///                     page.toolbarItems = [
///                         ToolbarItem("Save")
///                             .onClicked { save() },
///
///                         ToolbarItem("Delete")
///                             .order(.secondary)
///                             .isDestructive(true)
///                             .onClicked { delete() },
///                     ]
///                 }
///         }
///     }
///
/// A toolbar item is page furniture rather than a layout view. It carries a
/// caption, an optional image, presentation policy and a handler, and is
/// written into the page's session whenever that collection changes.
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
    public func order(_ value: ToolbarItemOrder) -> Self { setValue(.order, value.propValue) }

    /// Where this item sorts among items in the same order group.
    ///
    /// Lower values appear first. Items with equal priority retain source
    /// order, so one collection always produces one deterministic arrangement.
    public func priority(_ value: Int) -> Self { setValue(.priority, .number(Double(value))) }

    /// What it does. A second `.onClicked` runs beside the first, like every
    /// typed event modifier.
    ///
    /// Written here rather than on `MenuItemElement` because a `SwipeItem` is
    /// answered by `Invoked` instead - see that protocol.
    public func onClicked(_ handler: @escaping EventHandler) -> Self {
        modified { $0.addHandler(.clicked, handler) }
    }
}
