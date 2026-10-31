// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Which element's view shows an element, and which children a layout places, the same on every host.
/// Design: docs/design/host/pages.md#slots
extension MountedElement {
    /// The element whose view shows this one: itself where it presents a view, else the first it places that does.
    public var presentingElement: MountedElement? {
        !isViewless && native.presentsView ? self : arrangedChildren.lazy.compactMap(\.presentingElement).first
    }

    /// The children a layout places: all of them but what is declared on this element - a toolbar, a title view, a
    /// menu - which furnishes the chrome and stands in none of its room; an anchor's stand in its place.
    /// Design: docs/design/host/pages.md#an-anchor-stands-as-what-it-holds
    public var arrangedChildren: [MountedElement] {
        children.flatMap { child in
            NodeType.slotTypes.contains(child.type) ? [] : child.type == .anchor ? child.arrangedChildren : [child]
        }
    }

    /// The element placing this one among its arranged children: its parent, past an anchor standing between.
    public var placingParent: MountedElement? {
        guard let parent else { return nil }
        return parent.type == .anchor ? parent.placingParent : parent
    }
}
