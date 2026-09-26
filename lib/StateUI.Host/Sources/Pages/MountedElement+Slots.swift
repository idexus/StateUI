// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Which element's view shows an element, and what stands in a slot, the same on every host.
/// Design: docs/design/host/pages.md#slots
extension MountedElement {
    /// The element whose view shows this one: itself where it presents a view, else the first under it that does.
    public var presentingElement: MountedElement? {
        native.presentsView ? self : children.lazy.compactMap(\.presentingElement).first
    }

    /// The children a layout places: all of them, but a page's slots, which furnish its chrome and stand in none of
    /// its room.
    public var arrangedChildren: [MountedElement] {
        type == .page ? children.filter { !NodeType.slotTypes.contains($0.type) } : children
    }

    /// What stands in this element's `slot` - a page's title view, a title bar's content: the first element under
    /// the slot with a view; nil where none.
    public func slotContent(_ slot: NodeType) -> MountedElement? {
        children.first { $0.type == slot }?.children.lazy.compactMap(\.presentingElement).first
    }
}
