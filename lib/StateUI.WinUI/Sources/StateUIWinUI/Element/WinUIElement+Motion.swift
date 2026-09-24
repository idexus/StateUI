// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The element's part in its layout's motion: fading in as it joins, and a change of visibility crossed.
/// Design: docs/design/host/motion.md#layout-motion
extension WinUIElement {
    /// Hands a travelling layout what its children travel under, and tells it a patch reached it.
    func configureLayoutMotion() {
        guard let layout = view as? WinUITravellingLayout else { return }

        layout.layoutMotion = host?.layoutMotion
        layout.motion = element.motion
        layout.framesRead = element.framesRead
        layout.patchArrived()
    }

    /// Whether the element can fade in as it joins a standing layout: its view presents opacity, and no state owns it.
    var fadesIn: Bool {
        view != nil && element.driven[.opacity] == nil && WinUITransitionSurface.presents(.opacity, on: type)
    }

    /// Fades the element in as it joins a layout already standing; an opacity already on its way keeps its motion.
    func fadeIn(under motion: Motion) {
        guard fadesIn, let host, let view,
              host.tree.presentedPropertyValue(mount: element.mount, property: .opacity) == nil
        else { return }

        host.tree.receiveProperty(
            mount: element.mount, property: .opacity,
            standing: .number(0), target: element.resolvedValue(.opacity) ?? .number(1), motion: motion)
        view.setOpacity(value(.opacity)?.number ?? 1)
    }

    /// Crosses a change of visibility on an element already shown: out, fading and then hidden, or in from nothing,
    /// under the element's own motion or the application's; at once where nothing moves.
    func crossVisibility() {
        guard let host, let view else { return }

        let law = host.layoutMotion.law(of: element.motion)
        let opacity = element.resolvedValue(.opacity) ?? .number(1)

        if value(.isVisible)?.bool == false {
            guard view.isShown, !leaving, let law else { return }
            leaving = true
            let started = host.tree.receiveProperty(
                mount: element.mount, property: .opacity, standing: .number(view.opacity), target: .number(0),
                motion: law, landed: { [weak self] in self?.crossed() })
            if !started { leaving = false }
        } else if leaving {
            leaving = false
            host.tree.receiveProperty(
                mount: element.mount, property: .opacity, standing: .number(view.opacity), target: opacity,
                motion: law)
        } else if !view.isShown, let law {
            host.tree.receiveProperty(
                mount: element.mount, property: .opacity, standing: .number(0), target: opacity, motion: law)
            view.setOpacity(value(.opacity)?.number ?? 1)
        }
    }

    /// The fade out ended, landed or cut short: the element goes, and its layout closes over it as a patch moves it.
    func crossed() {
        guard leaving, let view else { return }

        leaving = false
        view.setShown(isShown)
        view.setOpacity(value(.opacity)?.number ?? 1)
        (layoutParent?.view as? WinUITravellingLayout)?.patchArrived()
        layoutParent?.arrangeChildren()
    }
}
