// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A press on a view that hears taps, followed as a button follows one: from the touch's fall to its lift - or to
/// UIKit taking it away, as a scroll begins - each phase told with where the touch stands in the view. It
/// recognizes nothing, so it keeps no other gesture from the touch.
/// Design: docs/design/platforms/uikit/input.md#a-press-as-a-button-takes-it
@MainActor
final class UIKitPressRecognizer: UIGestureRecognizer {
    /// What hears each phase of the press, where it stands in the view, and whether a finger presses.
    var onPress: ((GesturePhase, CGPoint, Bool) -> Void)?

    /// The touch the press follows, while one stands.
    private var touch: UITouch?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touch == nil, let first = touches.first else { return }
        touch = first
        tell(.began, first)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch, touches.contains(touch) { tell(.changed, touch) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch) else { return }
        self.touch = nil
        tell(.ended, touch)
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch) else { return }
        self.touch = nil
        tell(.cancelled, touch)
        state = .failed
    }

    /// Another gesture took the touch - a scroll, a swipe back: the press is taken away.
    override func reset() {
        if let touch {
            self.touch = nil
            tell(.cancelled, touch)
        }
        super.reset()
    }

    private func tell(_ phase: GesturePhase, _ touch: UITouch) {
        onPress?(phase, touch.location(in: view), touch.type == .direct)
    }
}
#endif
