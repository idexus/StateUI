// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An action on its page's bar - or, declared on a split view, on the part of its bar it names.
///
///     struct NotesPage: View {
///         var body: some View {
///             VStack { … }
///                 .toolbar {
///                     ToolbarButton("Save")
///                         .onClicked { save() }
///
///                     ToolbarButton("Delete")
///                         .role(.destructive)
///                         .placement(at: .overflow)
///                         .onClicked { delete() }
///                 }
///                 .title("Notes")
///         }
///     }
///
/// A toolbar button is page furniture rather than a layout view. Its words are
/// always its name - to assistive technology, in its tip and in the overflow -
/// and an item given an `icon` shows the picture alone unless `showsText`
/// says otherwise. Standing alone it says where it stands with `.placement`;
/// in a `ToolbarGroup` it stands where its group does.
public struct ToolbarButton: PlacedToolbarItem, MenuItemElement, ActionElement {
    /// The node this item describes.
    public var node: Node

    /// The group it stands in alone, which its placement is written on.
    var alone = Node(contract: ToolbarGroupContract.self)

    /// An item captioned `text`. Give it an `.onClicked`: an item that does
    /// nothing is one that looks broken.
    public init(_ text: String) {
        node = Node(contract: ToolbarButtonContract.self)
        node.write(MenuItemElementContract.text, text)
    }

    /// Who this item is among the others of its declaration, so an item
    /// inserted in the middle is matched to itself rather than to whichever
    /// stood there.
    ///
    /// - Parameter value: distinct among the declaration's items, and the same
    ///   value across renders.
    public func id(_ value: some Hashable) -> Modified {
        var copy = self
        copy.node.identify(value)
        return copy
    }

    /// Where the item stands, each part of it only where said: the part of
    /// its split view's bar - by default its declarer's - the edge of the bar
    /// or its overflow, and its order among the others there, lower earlier.
    ///
    ///     ToolbarButton("Add folder").placement(.sidebar, at: .start, order: 1)
    ///
    /// - Parameters:
    ///   - part: over the sidebar or over the detail; off any split view it
    ///     changes nothing.
    ///   - position: at the bar's start, its end - unsaid - or behind its
    ///     overflow menu.
    ///   - order: where it stands among the others at its position.
    public func placement(
        _ part: ToolbarPart? = nil, at position: ToolbarPosition? = nil, order: Int? = nil
    ) -> Modified {
        var copy = self
        copy.alone.place(part, at: position, order: order)
        return copy
    }

    /// Whether it hides with its split view's sidebar rather than move to the
    /// start of the detail's part while the sidebar is not shown.
    public func hidesWithSidebar(_ value: Bool) -> Modified {
        var copy = self
        copy.alone.write(ToolbarGroupContract.hidesWithSidebar, value)
        return copy
    }

    /// Whether the item shows its words beside its picture on the bar.
    ///
    /// Without it, an item given an `icon` shows the picture alone, its words
    /// in its tip and to assistive technology; an item with no picture always
    /// shows its words.
    public func showsText(_ value: Bool) -> Modified { setValue(ToolbarButtonContract.showsText, value) }

}

extension Node {
    /// Writes where a group of actions stands, each part only where said.
    mutating func place(_ part: ToolbarPart?, at position: ToolbarPosition?, order: Int?) {
        if let part { write(ToolbarGroupContract.part, part) }
        if let position { write(ToolbarGroupContract.position, position) }
        if let order { write(ToolbarGroupContract.order, order) }
    }
}
