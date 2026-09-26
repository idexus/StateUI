// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

// A swipe told from a press that moved: one rule for every host that hears
// the press itself.
// Design: docs/design/host/runtime.md#a-swipe

@_spi(Host)
extension SwipeDirection {
    /// The one direction a press that moved by (`x`, `y`) went - right and down positive - along the axis it moved
    /// most, where that movement reaches `threshold` and `listening` holds the direction; nil for no swipe.
    public static func swiped(x: Double, y: Double, listening: SwipeDirection, threshold: Double) -> SwipeDirection? {
        let across = abs(x) >= abs(y)
        let distance = across ? abs(x) : abs(y)
        guard distance > 0, distance >= max(0, threshold) else { return nil }

        let direction: SwipeDirection = across ? (x > 0 ? .right : .left) : (y < 0 ? .up : .down)
        return listening.contains(direction) ? direction : nil
    }
}
