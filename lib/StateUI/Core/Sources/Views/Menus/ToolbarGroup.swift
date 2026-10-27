// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Actions standing together on one shared background where the platform
/// draws one, in the order written, wherever the group stands.
///
///     .toolbar {
///         ToolbarGroup {
///             ToolbarButton("Bold").onClicked { bold() }
///             ToolbarButton("Italic").onClicked { italic() }
///         }
///         .placement(at: .start)
///     }
///
/// Behind the overflow menu a group is a section of it. An item in a group
/// stands where its group does: its own `.placement` is left out and said.
@MainActor
public struct ToolbarGroup: BarItemElement, BorderElement, PaddingElement, ToolbarGroupProperties {
    /// The group's node.
    public var node: Node

    /// A group of `items`, in reading order.
    public init(@ToolbarGroupBuilder _ items: () -> ToolbarGroupContent) {
        node = Node(contract: ToolbarGroupContract.self, children: items().items)
    }

    /// A group with nothing in it - what a `Style<ToolbarGroup>` is written for.
    public init() {
        node = Node(contract: ToolbarGroupContract.self)
    }

    /// Who this group is among the others of its declaration, so a group inserted before it is matched to itself
    /// rather than to whichever stood there.
    ///
    /// - Parameter value: distinct among the declaration's groups and items, and the same value across renders.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.identify(value)
        return copy
    }

    /// A copy with one thing changed: what every modifier of the group is built from.
    public func modified(_ change: (inout Node) -> Void) -> Self {
        var copy = self
        change(&copy.node)
        return copy
    }

    /// Where the group stands, each part of it only where said: the part of
    /// its split view's bar - by default its declarer's - the edge of the bar
    /// or its overflow, and its order among the others there, lower earlier.
    public func placement(
        _ part: ToolbarPart? = nil, at position: ToolbarPosition? = nil, order: Int? = nil
    ) -> Self {
        var copy = self
        copy.node.place(part, at: position, order: order)
        return copy
    }

    /// Whether it hides with its split view's sidebar rather than move to the
    /// start of the detail's part while the sidebar is not shown.
    public func hidesWithSidebar(_ value: Bool) -> Self {
        var copy = self
        copy.node.write(ToolbarGroupContract.hidesWithSidebar, value)
        return copy
    }

    /// Whether its items can be chosen: false leaves every one out of reach,
    /// as a disabled view does what it holds.
    public func isEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.node.write(ToolbarGroupContract.isEnabled, value)
        return copy
    }
}

/// What a group of a bar's actions says of itself - on the group, or in a `Style<ToolbarGroup>`.
public protocol ToolbarGroupProperties: PropertyContainer {}

extension ToolbarGroupProperties {
    /// The room between the group's items, where the host draws the bar itself - the Web; native bars keep their
    /// platform's room.
    ///
    ///     ToolbarGroup { … }.spacing(2).padding(3)
    public func spacing(_ value: Double) -> Modified { setValue(ToolbarGroupContract.spacing, value) }
}
