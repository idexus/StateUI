// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Which element's view shows an element, and which children a layout places, the same on every host.
/// Design: docs/design/host/pages.md#slots
extension MountedElement {
    /// The element whose view shows this one: itself where it presents a view, else the first it places that does.
    public var presentingElement: MountedElement? {
        native.presentsView ? self : arrangedChildren.lazy.compactMap(\.presentingElement).first
    }

    /// The children a layout places: all of them but what is declared on this element - a toolbar, a title view, a
    /// menu - which furnishes the chrome and stands in none of its room.
    public var arrangedChildren: [MountedElement] {
        children.filter { !NodeType.slotTypes.contains($0.type) }
    }
}
