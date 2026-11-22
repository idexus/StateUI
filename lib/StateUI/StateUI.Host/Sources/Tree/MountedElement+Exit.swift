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

    /// The views the element presents in the order they stand, each by the mount its layout knows it by - an
    /// arranged child's as `item` says, one kept as it leaves by its own - and the mounts of those kept.
    public func presentedMounts(item: (MountedElement) -> UInt64?) -> (mounts: [UInt64], kept: Set<UInt64>) {
        var (mounts, kept) = ([UInt64](), Set<UInt64>())
        for child in presentedChildren {
            if child.lifecycle == .exiting {
                mounts.append(child.mount)
                kept.insert(child.mount)
            } else if let mount = item(child) {
                mounts.append(mount)
            }
        }
        return (mounts, kept)
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
        guard lifecycle == .active, let tree, !tree.remakes, let effect = transition?.host.exit, !effect.isIdentity,
              let law = tree.layoutMotion.law(of: motion)
        else { return false }
        // An exit declared and not drawn is said to whoever waits for what the patch started.
        // Design: docs/design/host/motion.md#a-change-and-what-it-started
        guard parent.native.keepsExits, !holdsAnEngine else {
            tree.changes.refused(self, .unsupported)
            return false
        }
        guard tree.exits.admit(self, at: tree.time) else {
            tree.changes.refused(self, .limited)
            return false
        }

        // Where each number is drawn now is where it sets out: a motion on its way goes on from there. The place
        // its layout gave it is read here, before it is that layout's no more.
        exitPlace = tree.layoutMotion.placed(mount)?.place
        let sight = effect.outside == nil ? nil : placeInWhatShowsIt()
        let moved = effect.move(of: sight?.place, in: sight?.room)
        let ends: [(Prop, Double, Double)] = [
            (.opacity, 1, effect.opacity), (.translationX, 0, moved.x), (.translationY, 0, moved.y),
            (.scale, 1, effect.scale),
        ].map { property, unsaid, part in
            let declared = resolvedValue(property)?.number ?? unsaid
            return (property, declared, property == .opacity || property == .scale ? declared * part : declared + part)
        }
        deactivate(kept: true)
        parent.keptExits.append(self)
        for (property, declared, target) in ends {
            let standing = tree.presentedPropertyValue(mount: mount, property: property)?.number ?? declared
            // A number that landed stands at its end while the others travel, not as the view declared it.
            if target != declared { exitEnds[property] = target }
            guard standing != target else { continue }
            let started = tree.receiveProperty(
                mount: mount, property: property, standing: .number(standing), target: .number(target), motion: law,
                landed: { [weak self] in self?.exitLanded() })
            if started { exitsRunning += 1 }
        }
        if exitsRunning == 0 { endExit(.finished, arranging: true) }
        return true
    }

    /// One of the numbers the exit moves came to its end, landed or cut short.
    func exitLanded() {
        exitsRunning -= 1
        if exitsRunning <= 0, !isAbsorbed { endExit(.finished, arranging: true) }
    }

    /// The exit ends as `result`, once: the element is released, what kept it forgets it and arranges its views
    /// without it - the arrangement that takes its view out, left to the patch arranging it where `arranging` is
    /// false.
    func endExit(_ result: PresentationOperation.Result, arranging: Bool) {
        guard lifecycle == .exiting, let parent, parent.keptExits.contains(where: { $0 === self }) else { return }

        let presented = parent.presentedChildren
        parent.keptExits.removeAll { $0 === self }
        parent.orderPresented(after: presented)
        tree?.exits.ended(self, as: result)
        tree?.changes.exitEnds(mount, as: result)
        release()
        tree?.changes.released(mount)
        if arranging, parent.lifecycle == .active { parent.native.arrangeChildren() }
    }

    /// How a view was drawn as it left, for the one of its id that comes back: each number its exit moved, with
    /// its speed, and where its layout had placed it.
    struct Returned {
        var numbers: [Prop: (value: Double, velocity: [Double])] = [:]
        var place: Rect?
    }

    /// The numbers an entry and an exit move.
    static let presenceProperties: [(property: Prop, unsaid: Double)] = [
        (.opacity, 1), (.translationX, 0), (.translationY, 0), (.scale, 1),
    ]

    /// A child that comes as the one it returns as - of the id it is known by, and its type - is leaving takes
    /// that one's place in the drawing: the leaving one ends, interrupted, and the new one - another life, with
    /// handlers of its own - is handed how that one was drawn. Nothing is guessed by position. One drawn from a
    /// shared presentation is met through it instead.
    /// Design: docs/design/host/tree.md#the-same-view-coming-back
    func takeBack(_ children: [MountedElement], heldBefore before: [MountedElement]) {
        guard !keptExits.isEmpty, let tree else { return }

        for child in children where !before.contains(where: { $0 === child }) {
            let known = child.returnID
            guard let leaving = keptExits.first(where: {
                $0.returnID == known && $0.type == child.type && !$0.isAbsorbed && $0.presentation == nil
            })
            else { continue }

            var returned = Returned(place: leaving.exitPlace)
            for (property, unsaid) in Self.presenceProperties {
                let standing = tree.standingProperty(mount: leaving.mount, property: property)
                let value = standing?.value.number ?? leaving.exitEnds[property]
                    ?? leaving.resolvedValue(property)?.number ?? unsaid
                returned.numbers[property] = (value, standing?.velocity ?? [])
            }
            child.returned = returned
            leaving.endExit(.interrupted, arranging: false)
        }
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
