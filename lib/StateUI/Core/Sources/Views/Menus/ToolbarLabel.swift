// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Words on its page's bar that nobody chooses - most often on the bar at
/// the page's foot, a desktop's thin status bar or a phone's bottom toolbar.
///
///     struct InboxPage: View {
///         let unread: Int
///
///         var body: some View {
///             VStack { … }
///                 .toolbar(.bottom) {
///                     ToolbarLabel("\(unread) unread")
///                 }
///         }
///     }
///
/// It stands where an action would, by the same `.placement`, and behind the
/// overflow it is an entry nobody can choose.
public struct ToolbarLabel: PlacedToolbarItem, PropertyContainer {
    /// The node this item describes.
    public var node: Node

    /// The group it stands in alone, which its placement is written on.
    var alone = Node(contract: ToolbarGroupContract.self)

    /// An item showing `text`.
    public init(_ text: String) {
        node = Node(contract: ToolbarLabelContract.self)
        node.write(ToolbarLabelContract.text, text)
    }

    /// The picture before its words, resolved from the application's image
    /// resources.
    public func icon(_ value: ImageSource) -> Modified {
        setValue(ToolbarLabelContract.icon, value)
    }

    /// Who this item is among the others of its declaration, so an item
    /// inserted in the middle is matched to itself rather than to whichever
    /// stood there.
    public func id(_ value: some Hashable) -> Modified {
        var copy = self
        copy.node.identify(value)
        return copy
    }

    /// Where the item stands, each part of it only where said: the part of
    /// its split view's bar - by default its declarer's - the edge of the bar
    /// or its overflow, and its order among the others there, lower earlier.
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
}
