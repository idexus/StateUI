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
}

/// An element's showing, the same on every host: fading in as it joins a standing layout, and a change of its
/// visibility crossed - out, fading and then hidden; back from where it stands; in from nothing.
/// Design: docs/design/host/motion.md#showing-and-hiding
extension MountedElement {
    /// Whether the element stands shown: as the tree says, or while it fades out.
    public var standsShown: Bool {
        isLeaving || value(.isVisible)?.bool != false
    }

    /// Whether the element fades in as it joins a standing layout: its view `presentsOpacity`, and no state owns it.
    public func fadesIn(presentsOpacity: Bool) -> Bool {
        presentsOpacity && driven[.opacity] == nil
    }

    /// Fades the element in on `view` as it joins a layout already standing, under `motion`; an opacity already on its
    /// way keeps its motion.
    public func fadeIn(_ view: some FadingView, under motion: Motion) {
        guard let tree, tree.presentedPropertyValue(mount: mount, property: .opacity) == nil else { return }

        tree.receiveProperty(
            mount: mount, property: .opacity, standing: .number(0), target: resolvedValue(.opacity) ?? .number(1),
            motion: motion)
        view.setOpacity(value(.opacity)?.number ?? 1)
    }

    /// Crosses a change of visibility on `view`, already shown, under the element's own motion or the application's:
    /// hidden, it fades out and then hides, and `closed` lets its layout close over it; shown again as it fades, it
    /// comes back from where it stands; shown from nothing, it fades in. Where nothing moves, nothing crosses.
    public func crossVisibility<View: FadingView>(_ view: View, closed: @escaping () -> Void) {
        guard let tree else { return }

        let law = tree.layoutMotion.law(of: motion)
        let opacity = resolvedValue(.opacity) ?? .number(1)
        if value(.isVisible)?.bool == false {
            guard view.isShown, !isLeaving, let law else { return }
            isLeaving = true
            let started = tree.receiveProperty(
                mount: mount, property: .opacity, standing: .number(view.opacity), target: .number(0), motion: law,
                landed: { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.crossed(view, closed: closed)
                })
            if !started { isLeaving = false }
        } else if isLeaving {
            isLeaving = false
            tree.receiveProperty(
                mount: mount, property: .opacity, standing: .number(view.opacity), target: opacity, motion: law)
        } else if !view.isShown, let law {
            tree.receiveProperty(mount: mount, property: .opacity, standing: .number(0), target: opacity, motion: law)
            view.setOpacity(value(.opacity)?.number ?? 1)
        }
    }

    /// The fade out ended, landed or cut short: the view goes, and its layout closes over it.
    private func crossed(_ view: some FadingView, closed: () -> Void) {
        guard isLeaving else { return }

        isLeaving = false
        view.setShown(standsShown)
        view.setOpacity(value(.opacity)?.number ?? 1)
        closed()
    }
}
