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

        let sight = effect.outside == nil ? nil : placeInWhatShowsIt()
        let moved = effect.move(of: sight?.place, in: sight?.room)
        let starts: [(Prop, Double, Double)] = [
            (.opacity, 1, effect.opacity), (.translationX, 0, moved.x), (.translationY, 0, moved.y),
            (.scale, 1, effect.scale),
        ]
        var started: Set<Prop> = []
        for (property, unsaid, part) in starts {
            let declared = resolvedValue(property)?.number ?? unsaid
            let standing = property == .opacity || property == .scale ? declared * part : declared + part
            guard standing != declared, driven[property] == nil,
                  tree.presentedPropertyValue(mount: mount, property: property) == nil
            else { continue }

            if tree.receiveProperty(
                mount: mount, property: property, standing: .number(standing), target: .number(declared), motion: law
            ) { started.insert(property) }
        }
        presentsFromItsFirstFrame(started, on: view)
    }

    /// The element enters from the rectangle `source` onto the place `destination` its layout gave it, both in
    /// one window's coordinates: moved by the difference of their middles and scaled by the ratio of their
    /// sizes, each way apart, then brought onto what it declares under its own motion, else the application's.
    /// A number a state owns is left to it; with nothing to move by, it stands as declared. Each number sets out at
    /// its speed in `speeds`, its corner is carried on the way by `corner`, and it fades in over a partner drawn
    /// behind it as the two cross over in `crossing`, where one is. How many numbers set out, each telling
    /// `entryLanded` as it ends.
    /// Design: docs/design/host/motion.md#a-shared-transition
    func enter(
        from source: Rect, to destination: Rect, on view: some FadingView, speeds: [Prop: Double] = [:],
        corner: (from: Double, to: Double)? = nil, crossing: ClosedRange<Double>? = nil
    ) -> Int {
        guard let tree, let law = tree.layoutMotion.law(of: motion) else { return 0 }

        let across = source.x + source.width / 2 - destination.x - destination.width / 2
        let down = source.y + source.height / 2 - destination.y - destination.height / 2
        let starts: [(Prop, Double, Double, Bool)] = [
            (.translationX, 0, across, false), (.translationY, 0, down, false),
            (.scaleX, 1, source.width / destination.width, true), (.scaleY, 1, source.height / destination.height, true),
        ]
        var started: Set<Prop> = []
        var spans: [Prop: (from: Double, to: Double)] = [:]
        for (property, unsaid, part, scales) in starts where driven[property] == nil {
            let declared = resolvedValue(property)?.number ?? unsaid
            let standing = scales ? declared * part : declared + part
            let speed = speeds[property] ?? 0
            guard standing != declared || speed != 0 else { continue }
            spans[property] = (standing, declared)
            if tree.receiveProperty(
                mount: mount, property: property, standing: .number(standing), target: .number(declared), motion: law,
                landed: { [weak self] in self?.entryLanded() }, velocity: [speed]
            ) { started.insert(property) }
        }
        if !started.isEmpty, corner != nil || crossing != nil {
            way = SharedWay(spans: spans, corner: corner, comes: crossing.map { _ in true },
                            crossing: crossing ?? 0...1)
            if corner != nil, let rounding = roundingProperty { started.insert(rounding) }
        }
        presentsFromItsFirstFrame(started, on: view)
        return started.subtracting([.cornerRadius, .shape]).count
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
        var started: Set<Prop> = []
        for (property, unsaid) in Self.presenceProperties where driven[property] == nil {
            guard let drawn = returned.numbers[property] else { continue }
            let declared = resolvedValue(property)?.number ?? unsaid
            let standing = drawn.value + (property == .translationX ? across : property == .translationY ? down : 0)
            guard standing != declared || !drawn.velocity.isEmpty else { continue }
            if tree.receiveProperty(
                mount: mount, property: property, standing: .number(standing), target: .number(declared), motion: law,
                velocity: drawn.velocity
            ) { started.insert(property) }
        }
        presentsFromItsFirstFrame(started, on: view)
    }

    /// An entry is drawn where it sets out from the frame its first place is given in, never at that place
    /// first: its opacity on `view`, and every other number it `started` on the element's view, at once - not at
    /// the display's next frame, which comes after the toolkit has drawn this one.
    /// Design: docs/design/host/motion.md#a-view-that-enters
    private func presentsFromItsFirstFrame(_ started: Set<Prop>, on view: some FadingView) {
        view.setOpacity(value(.opacity)?.number ?? 1)
        let drawn = started.subtracting([.opacity])
        if !drawn.isEmpty { native.presentFrame(drawn) }
    }
}
