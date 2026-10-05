// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The element's part in its layout's motion: its children travelling to their places, fading in as it joins, and a
/// change of visibility crossed - each by the host layer's rule.
/// Design: docs/design/host/motion.md#layout-motion
extension WebElement {
    /// Hands a travelling layout what its children travel under and who reads their places, and tells it a patch
    /// reached it.
    func configureLayoutMotion() {
        guard let layout = view as? WebLayoutView, layout.travels, let host else { return }
        layout.placing = host.placements
        host.placements.follow(layout)
        layout.places.layoutMotion = host.runtime.layoutMotion
        layout.places.motion = element.motion
        layout.places.framesRead = element.framesRead
        layout.places.patchArrived()
    }

    /// Whether the element fades in as it joins a standing layout, by the host layer's rule.
    var fadesIn: Bool {
        view != nil && element.fadesIn(presentsOpacity: WebTransitionSurface.presents(.opacity, on: type))
    }

    /// Fades the element in as it joins a layout already standing, by the host layer's rule.
    func fadeIn(under motion: Motion) {
        guard fadesIn, let view else { return }
        element.fadeIn(view, under: motion)
    }

    /// Crosses a change of visibility by the host layer's rule; as a fade out ends, the layout closes over it.
    func crossVisibility() {
        guard let view else { return }
        element.crossVisibility(view) { [weak self] in
            guard let layout = self?.layoutParent else { return }
            (layout.view as? WebLayoutView)?.places.patchArrived()
            layout.arrangeChildren()
        }
    }
}
