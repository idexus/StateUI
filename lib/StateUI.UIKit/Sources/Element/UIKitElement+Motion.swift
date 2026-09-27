// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The element's part in its layout's motion: its children travelling to their places, fading in as it joins, and
/// a change of visibility crossed - each by the host layer's rule.
/// Design: docs/design/platforms/uikit/motion.md
extension UIKitElement {
    /// Hands a layout what its children travel under, and tells it a patch reached it.
    func configureLayoutMotion() {
        guard let layout = view as? UIKitLayoutView else { return }
        layout.places.layoutMotion = host?.runtime.layoutMotion
        layout.places.motion = element.motion
        layout.places.framesRead = element.framesRead
        layout.places.patchArrived()
    }

    /// Whether the element fades in as it joins a standing layout, by the host layer's rule.
    var fadesIn: Bool {
        drawing != nil && element.fadesIn(presentsOpacity: TransitionSurface.presents(.opacity, on: type))
    }

    /// Fades the element in as it joins a layout already standing, by the host layer's rule.
    func fadeIn(under motion: Motion) {
        guard fadesIn, let drawing else { return }
        element.fadeIn(drawing, under: motion)
    }

    /// Crosses a change of visibility by the host layer's rule; as a fade out ends, the layout closes over it.
    func crossVisibility() {
        guard let drawing else { return }
        element.crossVisibility(drawing) { [weak self] in
            guard let layout = self?.placingParent else { return }
            (layout.view as? UIKitLayoutView)?.places.patchArrived()
            layout.arrangeChildren()
        }
    }

    /// The element whose layout places this one: the nearest above it with a view.
    var placingParent: UIKitElement? {
        guard let parent else { return nil }
        return parent.view != nil ? parent : parent.placingParent
    }
}

/// A view fades by its drawing: its own opacity, and whether UIKit shows it.
extension UIKitViewDrawing: FadingView {
    var isShown: Bool { view?.isHidden == false }

    func setShown(_ shown: Bool) {
        view?.isHidden = !shown
    }

    func setOpacity(_ opacity: Double) {
        ownOpacity = opacity
    }
}
#endif
