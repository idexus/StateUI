// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What stands on a bar: a `ToolbarButton` - an action, a menu or both - or a `ToolbarToggle`, a setting, standing
/// alone or in a `ToolbarGroup`.
///
///     .toolbar {
///         ToolbarButton("Save").onClicked { save() }
///     }
@MainActor
public protocol ToolbarItem: Element {}

/// An item that says where it stands when it stands alone: its group of one, its placement written on it.
@MainActor
protocol PlacedToolbarItem: ToolbarItem {
    /// The group it stands in alone.
    var alone: Node { get }
}

extension ToolbarItem {
    /// The group of its own the item stands in alone.
    var standingAlone: Node {
        var group = (self as? any PlacedToolbarItem)?.alone ?? Node(contract: ToolbarGroupContract.self)
        group.write(ToolbarGroupContract.standsAlone, true)
        group.children = [node]
        return group
    }

    /// The item as a group holds it: its own placement left out, and said once.
    var held: Node {
        if let placed = self as? any PlacedToolbarItem, !placed.alone.props.isEmpty {
            complain("A toolbar item in a ToolbarGroup stands where its group does: its placement was left out")
        }
        return node
    }
}
