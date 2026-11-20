// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The element's part in its layout's motion: fading in as it joins, and a change of visibility crossed,
/// both by the host layer's rule.
/// Design: docs/design/host/motion.md#layout-motion
extension WinUIElement {
    /// Hands a traveling layout what its children travel under, and tells it a patch reached it.
    func configureLayoutMotion() {
        guard let layout = view as? WinUITravelingLayout else { return }

        layout.places.layoutMotion = host?.runtime.layoutMotion
        layout.places.motion = element.motion
        layout.places.patchArrived()
    }

    /// Whether the element may come moving as it is given its first place, by the host layer's rule.
    var entersMoving: Bool {
        view != nil && element.entersMoving(presentsOpacity: TransitionSurface.presents(.opacity, on: type))
    }

    /// Brings the element in as it is given its first place, by the host layer's rule.
    func enter(_ entry: LayoutEntry) {
        guard entersMoving, let view else { return }
        element.enter(view, as: entry)
    }

    /// Crosses a change of visibility by the host layer's rule; as a fade out ends, the layout closes over it.
    func crossVisibility() {
        guard let view else { return }
        element.crossVisibility(view, closingIn: (layoutParent?.view as? WinUITravelingLayout)?.places)
    }
}

extension WinUIView: FadingView {}
