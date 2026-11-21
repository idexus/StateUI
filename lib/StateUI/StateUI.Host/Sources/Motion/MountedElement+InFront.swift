// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A view setting out from its partner is drawn in front of what it passes over until it lands, up to its scope:
/// in a layout that does not layer its children, in front of them all; in one that does, of those that stood
/// before it - what came with it keeps the order its author layered.
/// Design: docs/design/host/motion.md#drawn-in-front
extension MountedElement {
    /// A child drawn in front in the layout that holds it, by its mount.
    struct RaisedChild {
        let mount: UInt64
        weak var layout: MountedElement?
    }

    /// Draws this element, and each layout holding it up to the scope `scope`, in front, until its entry's `runs`
    /// numbers have landed.
    func drawInFront(under scope: UInt64, runs: Int) {
        guard let tree, runs > 0 else { return }

        var child = self
        while let layout = child.layoutParent {
            if !Self.layered.contains(layout.type) || !tree.shared.isNew(layout) {
                tree.layoutMotion.raise(child.mount)
                raisedByEntry.append(RaisedChild(mount: child.mount, layout: layout))
                layout.native.orderChildren()
            }
            if layout.mount == scope { break }
            child = layout
        }
        entryRunsLeft = runs
    }

    /// One of the numbers the entry moves came to its end, landed or cut short: after the last, what it drew in
    /// front stands back in its layout's order.
    func entryLanded() {
        entryRunsLeft -= 1
        if entryRunsLeft <= 0 { lowerEntry() }
    }

    /// What the entry drew in front stands back in its layout's order.
    func lowerEntry() {
        guard let tree, !raisedByEntry.isEmpty else { return }

        let raised = raisedByEntry
        (raisedByEntry, entryRunsLeft) = ([], 0)
        for each in raised { tree.layoutMotion.lower(each.mount) }
        for each in raised { each.layout?.native.orderChildren() }
    }
}
