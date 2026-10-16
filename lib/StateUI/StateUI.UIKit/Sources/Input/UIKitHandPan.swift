// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
import UIKit.UIGestureRecognizerSubclass
@_spi(Host) import StateUI

/// The hand over a layout as UIKit's pan tells it, and the press it begins with: where a finger goes down, told at
/// once - a press standing still may hold a view - and its lift where it never moved as a drag.
/// Design: docs/design/platforms/uikit/input.md#the-hand-over-a-layout
@MainActor
final class UIKitHandPan: UIPanGestureRecognizer {
    /// What a finger going down tells - where, in the view - and what its lift undragged tells: whether it was taken
    /// away.
    var onPress: ((Point) -> Void)?
    var onLift: ((Bool) -> Void)?

    /// Whether a finger is down, told, and whether it moved as a drag, which the pan's own end tells.
    private(set) var pressing = false
    var dragging = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard !pressing, let touch = touches.first, let view else { return }

        pressing = true
        let at = touch.location(in: view)
        onPress?(Point(x: Double(at.x), y: Double(at.y)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        lifted(cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        lifted(cancelled: true)
    }

    override func reset() {
        super.reset()
        pressing = false
        dragging = false
    }

    /// The finger lifted or taken away: told where the press never moved as a drag.
    private func lifted(cancelled: Bool) {
        guard pressing, !dragging, numberOfTouches <= 1 else { return }

        pressing = false
        onLift?(cancelled)
    }
}
#endif
