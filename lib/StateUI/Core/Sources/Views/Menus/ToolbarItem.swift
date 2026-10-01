// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An action in the page's native navigation or toolbar surface.
///
///     struct NotesPage: ContentView {
///         @Environment private var page: PageSession
///
///         var content: some View {
///             VStack { … }
///                 .toolbar {
///                     ToolbarItem("Save")
///                         .onClicked { save() }
///
///                     ToolbarItem("Delete")
///                         .placement(.overflow)
///                         .isDestructive(true)
///                         .onClicked { delete() }
///                 }
///                 .onCreated { page.title = "Notes" }
///         }
///     }
///
/// A toolbar item is page furniture rather than a layout view. It carries a
/// caption, an optional image, presentation policy and a handler, and stands
/// in a group a `.toolbar { }` declares.
public struct ToolbarItem: Element, MenuItemElement {
    /// The node this item describes.
    public var node: Node

    /// An item captioned `text`. Give it an `.onClicked`: an item that does
    /// nothing is one that looks broken.
    public init(_ text: String) {
        node = Node(contract: ToolbarItemContract.self)
        node.write(MenuItemElementContract.text, text)
    }

    /// The node this item describes.
    public var body: Node { node }

    /// Who this item is among the page's others, so an item inserted in the
    /// middle is matched to itself rather than to whichever item stood there.
    /// An item with the id of one declared around its page stands in that
    /// item's place while the page is shown.
    ///
    /// - Parameter value: distinct among the page's items, and the same value
    ///   across renders.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.id = String(describing: value)
        return copy
    }

    /// Whether it sits on the bar itself or behind the overflow menu.
    public func placement(_ value: ToolbarItemPlacement) -> Self { setValue(ToolbarItemContract.placement, value) }

    /// Whether the item shows its words beside its picture on the bar.
    ///
    /// Without it, an item given an `icon` shows the picture alone, its words
    /// in its tip and to assistive technology; an item with no picture always
    /// shows its words.
    public func showsText(_ value: Bool) -> Self { setValue(ToolbarItemContract.showsText, value) }
}
