// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The element's part in its layout's motion: its children traveling to their places, fading in as it joins, and a
/// change of visibility crossed - each by the host layer's rule.
/// Design: docs/design/host/motion.md#layout-motion
extension WebElement {
    /// Hands a layout the runtime's layout motion - which child a shared entry draws in front - and a traveling one
    /// what its children travel under and who reads their places, and tells it a patch reached it.
    func configureLayoutMotion() {
        guard let layout = view as? WebLayoutView, let host else { return }
        layout.places.layoutMotion = host.runtime.layoutMotion
        guard layout.travels else { return }
        layout.placing = host.placements
        host.placements.follow(layout)
        layout.places.motion = element.motion
        layout.places.patchArrived()
    }

    /// Whether the element may come moving as it is given its first place, by the host layer's rule.
    var entersMoving: Bool {
        view != nil && element.entersMoving(presentsOpacity: WebTransitionSurface.presents(.opacity, on: type))
    }

    /// The layouts from the element's own view up through its ancestors' to the page's root, nearest first: whose
    /// children a change of the element may move.
    var layoutsUp: [WebLayoutView] {
        sequence(first: element, next: { $0.parent }).compactMap { ($0.native as? WebElement)?.view as? WebLayoutView }
    }

    /// Brings the element in as it is given its first place, by the host layer's rule.
    func enter(_ entry: LayoutEntry) {
        guard entersMoving, let view else { return }
        element.enter(view, as: entry)
    }

    /// Crosses a change of visibility by the host layer's rule; as a fade out ends, the layout closes over it.
    func crossVisibility() {
        guard let view else { return }
        element.crossVisibility(view, closingIn: (layoutParent?.view as? WebLayoutView)?.places)
    }
}
