// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A native view whose showing and opacity the host layer's visibility rule moves.
@_spi(Host) @MainActor public protocol FadingView: AnyObject {
    /// Whether the view is shown.
    var isShown: Bool { get }

    /// The opacity the view stands at.
    var opacity: Double { get }

    /// Shows or hides the view.
    func setShown(_ shown: Bool)

    /// Stands the view at `opacity`.
    func setOpacity(_ opacity: Double)

    /// Makes the view and everything in it deaf to input, a press going to what stands behind it, or lets it hear.
    func setIgnoresInput(_ ignores: Bool)
}

/// An element's showing, the same on every host: entering as it is given its first place, and a change of its
/// visibility crossed - out, fading and then hidden; back from where it stands; in from nothing.
/// Design: docs/design/host/motion.md#showing-and-hiding
extension MountedElement {
    /// Whether the element stands shown: as the tree says, or while it fades out.
    public var standsShown: Bool {
        isFadingOut || value(.isVisible)?.bool != false
    }

    /// Whether the element answers no input: as the tree says, while it fades out (`presented`), or kept as it
    /// leaves - a press then reaches what stands behind it.
    public var ignoresInput: Bool {
        lifecycle == .exiting || presented(.ignoresInput)?.bool == true
    }

    /// Whether the element may come moving as it is given its first place: by the transition it declares, else
    /// fading in where its view `presentsOpacity` and no state owns it.
    public func entersMoving(presentsOpacity: Bool) -> Bool {
        transition != nil || value(ViewContract.sharedTransition.token) != nil
            || (presentsOpacity && driven[.opacity] == nil)
    }

    /// The element enters on `view` as it is given its first place. Declaring a transition, it comes from the
    /// entry's effect under its own motion: as it joins a layout already standing, and as it appears with its
    /// layout where the transition says so. Declaring none, it fades in under the law of the layout it joins -
    /// unless a view made with it, under it, sets out from its partner: then it comes as it stands. An element a
    /// message made again enters by no transition.
    /// Design: docs/design/host/motion.md#a-view-that-enters
    public func enter(_ view: some FadingView, as entry: LayoutEntry) {
        if let returned {
            self.returned = nil
            return comeBack(as: returned, on: view)
        }
        // One view left wearing the key this one wears: it sets out from where that one was drawn.
        if !isRemade, let tree, let shared = tree.shared.source(for: self, in: tree) {
            shared.leaving?.endExit(.interrupted, arranging: true)
            return drawInFront(under: shared.scope, runs: enter(from: shared.from, to: shared.to, on: view))
        }
        guard let transition = transition?.host else {
            if case .joining(let law) = entry, law.animates, tree?.shared.holdsAPartner(self) != true {
                fadeIn(view, under: law)
            }
            return
        }
        guard !isRemade, entry != .appearing || transition.entersInitially else { return }

        enter(by: transition.enter, on: view)
    }

    /// Fades the element in on `view` under `motion`; an opacity already on its way keeps its motion.
    private func fadeIn(_ view: some FadingView, under motion: Motion) {
        guard let tree, tree.presentedPropertyValue(mount: mount, property: .opacity) == nil else { return }

        tree.receiveProperty(
            mount: mount, property: .opacity, standing: .number(0), target: resolvedValue(.opacity) ?? .number(1),
            motion: motion)
        view.setOpacity(value(.opacity)?.number ?? 1)
    }

    /// Crosses a change of visibility on `view`, already shown, under the element's own motion or the application's:
    /// hidden, it fades out deaf to input and then hides, and the layout placing it closes over it - `places`, its
    /// parent's traveling places, told the change arrived; shown again as it fades, it comes back from where it
    /// stands and hears again; shown from nothing, it fades in. Where nothing moves, nothing crosses.
    public func crossVisibility<View: FadingView>(_ view: View, closingIn places: TravelingPlaces?) {
        guard let tree else { return }

        let law = tree.layoutMotion.law(of: motion)
        let opacity = resolvedValue(.opacity) ?? .number(1)
        if value(.isVisible)?.bool == false {
            guard view.isShown, !isFadingOut, let law else { return }
            isFadingOut = true
            view.setIgnoresInput(true)
            let started = tree.receiveProperty(
                mount: mount, property: .opacity, standing: .number(view.opacity), target: .number(0), motion: law,
                landed: { [weak self, weak view, weak places] in
                    guard let self, let view else { return }
                    self.crossed(view, closingIn: places)
                })
            if !started {
                isFadingOut = false
                view.setIgnoresInput(ignoresInput)
            }
        } else if isFadingOut {
            isFadingOut = false
            view.setIgnoresInput(ignoresInput)
            tree.receiveProperty(
                mount: mount, property: .opacity, standing: .number(view.opacity), target: opacity, motion: law)
        } else if !view.isShown, let law {
            tree.receiveProperty(mount: mount, property: .opacity, standing: .number(0), target: opacity, motion: law)
            view.setOpacity(value(.opacity)?.number ?? 1)
        }
    }

    /// The fade out ended, landed or cut short: the view goes, and its layout closes over it.
    private func crossed(_ view: some FadingView, closingIn places: TravelingPlaces?) {
        guard isFadingOut else { return }

        isFadingOut = false
        view.setIgnoresInput(ignoresInput)
        view.setShown(standsShown)
        view.setOpacity(value(.opacity)?.number ?? 1)
        places?.patchArrived()
        // Closing over it is the change hiding it at once would be: every layout around it travels to its new
        // places and measures again. Design: docs/design/host/motion.md#showing-and-hiding
        guard let parent = layoutParent else { return }
        for layout in parent.measuredUpward().layouts { layout.native.configureLayoutMotion() }
        parent.native.invalidateMeasurements()
        parent.native.arrangeChildren()
    }

    /// The element whose layout places this one: the nearest above it with a view.
    public var layoutParent: MountedElement? {
        guard let parent else { return nil }
        return parent.native.presentsView ? parent : parent.layoutParent
    }
}
