// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// An element's coming by the transition it declares, the same on every host: each number the entry's effect
/// touches set out from the effect and brought onto what the element declares, by the road a property's own
/// animation takes - so no host draws it by anything new.
/// Design: docs/design/host/motion.md#a-view-that-enters
extension MountedElement {
    /// The transition the element declares; nil where it declares none.
    public var transition: Transition? {
        value(ViewContract.transition.token).flatMap(Transition.init(propValue:))
    }

    /// The element enters from `effect` on `view` under its own motion, else the application's: its opacity from
    /// what it declares times the effect's, its move from what it declares plus the effect's - an effect out of
    /// its room, as far as takes it wholly out of the room its layout placed it in - its scale from what it
    /// declares times the factor. A number a state owns, or one already on its way, is left to it; where nothing
    /// moves, the element stands as declared.
    func enter(by effect: HostTransitionEffect, on view: some FadingView) {
        guard let tree, let law = tree.layoutMotion.law(of: motion) else { return }

        let placed = tree.layoutMotion.placed(mount)
        let moved = effect.move(of: placed?.place, in: placed?.room)
        let starts: [(Prop, Double, Double)] = [
            (.opacity, 1, effect.opacity), (.translationX, 0, moved.x), (.translationY, 0, moved.y),
            (.scale, 1, effect.scale),
        ]
        for (property, unsaid, part) in starts {
            let declared = resolvedValue(property)?.number ?? unsaid
            let standing = property == .opacity || property == .scale ? declared * part : declared + part
            guard standing != declared, driven[property] == nil,
                  tree.presentedPropertyValue(mount: mount, property: property) == nil
            else { continue }

            tree.receiveProperty(
                mount: mount, property: property, standing: .number(standing), target: .number(declared), motion: law)
        }
        view.setOpacity(value(.opacity)?.number ?? 1)
    }

    /// The element comes back as the view of its id was leaving: each number goes on from where that one was
    /// drawn, at its speed, onto what the element declares - its move from where that one stood, should its
    /// layout place it elsewhere - under its own motion, else the application's; with nothing to move by it
    /// stands as declared.
    /// Design: docs/design/host/tree.md#the-same-view-coming-back
    func comeBack(as returned: Returned, on view: some FadingView) {
        guard let tree else { return }

        let law = tree.layoutMotion.law(of: motion)
        let place = tree.layoutMotion.placed(mount)?.place
        let across = returned.place.flatMap { old in place.map { old.x - $0.x } } ?? 0
        let down = returned.place.flatMap { old in place.map { old.y - $0.y } } ?? 0
        for (property, unsaid) in Self.presenceProperties where driven[property] == nil {
            guard let drawn = returned.numbers[property] else { continue }
            let declared = resolvedValue(property)?.number ?? unsaid
            let standing = drawn.value + (property == .translationX ? across : property == .translationY ? down : 0)
            guard standing != declared || !drawn.velocity.isEmpty else { continue }
            tree.receiveProperty(
                mount: mount, property: property, standing: .number(standing), target: .number(declared), motion: law,
                velocity: drawn.velocity)
        }
        view.setOpacity(value(.opacity)?.number ?? 1)
    }
}
