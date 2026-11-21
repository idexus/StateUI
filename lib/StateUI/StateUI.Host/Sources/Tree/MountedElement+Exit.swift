// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A view kept as it leaves: no more the application's at once, drawn on by the exit its transition declares, and
/// released as that ends - the same on every host whose view keeps one.
/// Design: docs/design/host/tree.md#a-view-kept-as-it-leaves
extension MountedElement {
    /// The element's views in the order they stand natively and are drawn: its arranged children, and those kept
    /// as they leave where they left from. What is measured, laid out and reached is `arrangedChildren` alone.
    public var presentedChildren: [MountedElement] {
        keptExits.isEmpty ? arrangedChildren : Self.order(arrangedChildren, keeping: keptExits, asIn: presentedOrder ?? [])
    }

    /// How many mounted elements stand in this subtree.
    var mountCount: Int {
        held.reduce(1) { $0 + $1.mountCount }
    }

    /// Whether an engine of its own runs in this subtree: a web view's, a map's (`NodeType.engineTypes`).
    var holdsAnEngine: Bool {
        NodeType.engineTypes.contains(type) || held.contains(where: \.holdsAnEngine)
    }

    /// Begins the element's exit from `parent`: kept where it declares a transition whose exit changes something,
    /// `parent`'s view keeps a view that left, its own motion - else the application's - animates, no message
    /// makes the tree again, no engine runs under it, and the window's budget holds. False where it is to leave
    /// at once.
    func exit(from parent: MountedElement) -> Bool {
        guard lifecycle == .active, let tree, !tree.remakes, parent.native.keepsExits,
              let effect = transition?.host.exit, !effect.isIdentity, !holdsAnEngine,
              let law = tree.layoutMotion.law(of: motion), tree.exits.admit(self, at: tree.time)
        else { return false }

        // Where each number is drawn now is where it sets out: a motion on its way goes on from there.
        let ends: [(Prop, Double, Double)] = [
            (.opacity, 1, effect.opacity), (.translationX, 0, effect.translation.x),
            (.translationY, 0, effect.translation.y), (.scale, 1, effect.scale),
        ].map { property, unsaid, part in
            let declared = resolvedValue(property)?.number ?? unsaid
            return (property, declared, property == .opacity || property == .scale ? declared * part : declared + part)
        }
        deactivate(kept: true)
        parent.keptExits.append(self)
        for (property, declared, target) in ends {
            let standing = tree.presentedPropertyValue(mount: mount, property: property)?.number ?? declared
            guard standing != target else { continue }
            let started = tree.receiveProperty(
                mount: mount, property: property, standing: .number(standing), target: .number(target), motion: law,
                landed: { [weak self] in self?.exitLanded() })
            if started { exitsRunning += 1 }
        }
        if exitsRunning == 0 { endExit(.finished) }
        return true
    }

    /// One of the numbers the exit moves came to its end, landed or cut short.
    private func exitLanded() {
        exitsRunning -= 1
        if exitsRunning <= 0, !isAbsorbed { endExit(.finished) }
    }

    /// The exit ends as `result`, once: the element is released, what kept it forgets it and arranges its views
    /// without it - the arrangement that takes its view out.
    func endExit(_ result: PresentationOperation.Result) {
        guard lifecycle == .exiting, let parent, parent.keptExits.contains(where: { $0 === self }) else { return }

        let presented = parent.presentedChildren
        parent.keptExits.removeAll { $0 === self }
        parent.orderPresented(after: presented)
        tree?.exits.ended(self, as: result)
        release()
        if parent.lifecycle == .active { parent.native.arrangeChildren() }
    }

    /// An element holding this one leaves: the exit is that element's leaving's part - it runs no end of its own,
    /// and stands as drawn until that element is released.
    func absorbed() {
        guard !isAbsorbed else { return }

        isAbsorbed = true
        tree?.exits.ended(self, as: .cancelled)
    }

    /// Remembers the order the views stand in, from how they stood - `previous` - and what is arranged now.
    func orderPresented(after previous: [MountedElement]) {
        presentedOrder = keptExits.isEmpty ? nil : Self.order(arrangedChildren, keeping: keptExits, asIn: previous)
    }

    /// `arranged` with each of `kept` after the view it stood after in `previous`; one `previous` never held
    /// stands last.
    private static func order(
        _ arranged: [MountedElement], keeping kept: [MountedElement], asIn previous: [MountedElement]
    ) -> [MountedElement] {
        var order = arranged
        let active = Set(arranged.map(ObjectIdentifier.init))
        var waiting = Set(kept.map(ObjectIdentifier.init))
        var last: MountedElement?
        for element in previous {
            if waiting.remove(ObjectIdentifier(element)) != nil {
                let place = last.flatMap { last in order.firstIndex { $0 === last } }.map { $0 + 1 } ?? 0
                order.insert(element, at: place)
                last = element
            } else if active.contains(ObjectIdentifier(element)) {
                last = element
            }
        }
        return order + kept.filter { waiting.contains(ObjectIdentifier($0)) }
    }
}
