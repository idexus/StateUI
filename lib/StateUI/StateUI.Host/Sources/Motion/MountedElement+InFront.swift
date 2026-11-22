// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A view setting out from its partner is drawn in front of what it passes over until it lands, up to its scope:
/// in a layout that does not layer its children, in front of them all; in one that does, of those that stood
/// before it - what came with it keeps the order its author layered. The keyed view of the partner kept for it goes
/// along so too, and in the first layout holding both, the larger of the two is in front.
/// Design: docs/design/host/motion.md#drawn-in-front
extension MountedElement {
    /// A child drawn in front in the layout that holds it, by its mount.
    struct RaisedChild {
        let mount: UInt64
        weak var layout: MountedElement?
    }

    /// Draws this element, and each layout holding it up to the scope `scope`, in front, until its entry's `runs`
    /// numbers have landed - in the first layout holding `partner`, kept for it, only where it `leads`.
    func drawInFront(under scope: UInt64, runs: Int, besides partner: MountedElement? = nil, leads: Bool = true) {
        guard runs > 0 else { return }
        raise(under: scope, besides: partner, leads: leads)
        entryRunsLeft = runs
    }

    /// Draws this element, the keyed view of the one kept for `partner` as it goes along, and each layout holding it
    /// in front up to the scope `scope` - in the first layout holding `partner` too, only where it `leads` - until
    /// it is released.
    func drawKeptInFront(under scope: UInt64, besides partner: MountedElement, leads: Bool) {
        guard lifecycle == .exiting else { return }
        raise(under: scope, besides: partner, leads: leads)
    }

    /// Draws this element and each layout holding it in front in what holds it, up to the scope `scope` - in the
    /// first layout that holds `partner` too, only where it `leads`.
    private func raise(under scope: UInt64, besides partner: MountedElement?, leads: Bool) {
        guard let tree else { return }

        var theirs = Set<ObjectIdentifier>()
        var each = partner
        while let element = each, element.mount != scope, let layout = element.layoutParent {
            theirs.insert(ObjectIdentifier(layout))
            each = layout
        }
        var child = self
        while child.mount != scope, let layout = child.layoutParent {
            let shared = theirs.remove(ObjectIdentifier(layout)) != nil
            if shared { theirs = [] }
            if (!shared || leads), !Self.layered.contains(layout.type) || !tree.shared.isNew(layout) {
                tree.layoutMotion.raise(child.mount)
                raisedByEntry.append(RaisedChild(mount: child.mount, layout: layout))
                layout.native.orderChildren()
            }
            child = layout
        }
    }

    /// One of the numbers the entry moves came to its end, landed or cut short: after the last, what it drew in
    /// front stands back in its layout's order.
    func entryLanded() {
        entryRunsLeft -= 1
        guard entryRunsLeft <= 0 else { return }
        lowerEntry()
        endWay()
    }

    /// The way ends: what it worked out stands as the element declares it again.
    func endWay() {
        guard let way else { return }
        self.way = nil
        var presented: Set<Prop> = way.comes != nil ? [.opacity] : []
        if way.corner != nil, let rounding = roundingProperty { presented.insert(rounding) }
        if !presented.isEmpty { native.presentFrame(presented) }
    }

    /// What the entry drew in front stands back in its layout's order.
    func lowerEntry() {
        guard let tree, !raisedByEntry.isEmpty else { return }

        let raised = raisedByEntry
        (raisedByEntry, entryRunsLeft) = ([], 0)
        for each in raised { tree.layoutMotion.lower(each.mount) }
        for each in raised where each.layout?.lifecycle != .released { each.layout?.native.orderChildren() }
    }
}
