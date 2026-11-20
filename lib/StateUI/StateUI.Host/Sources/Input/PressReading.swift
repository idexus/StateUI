// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A view's own press as its effect is handed it: where it went down, how fast it goes, and what of it waits for
/// the next frame - a press told faster than the display draws is asked of once a frame.
/// Design: docs/design/host/interaction.md#a-views-own-press-and-drag
struct PressReading: Sendable {
    /// Where the press went down, and where it last stood; nil while none stands.
    private var from: Point?
    private var last = Point.zero

    private var trail = SpeedReading()

    /// The press as it stood when it was last told, waiting for a frame.
    private(set) var waiting: PressInput?

    /// Whether a press stands on the view.
    var isDown: Bool { from != nil }

    /// A press at `phase` standing at `point` of a view `size` large, at `time`: what the effect is handed for it,
    /// kept for the next frame - nil for a step of a press that never went down.
    mutating func told(_ phase: GesturePhase, at point: Point, size: LayoutSize, time: Double) {
        if phase == .began {
            (from, last, trail) = (point, point, SpeedReading())
        }
        guard let from else { return }

        trail.moved(Point(x: point.x - last.x, y: point.y - last.y), at: time)
        last = point
        waiting = PressInput(
            phase: phase, location: point, displacement: Point(x: point.x - from.x, y: point.y - from.y),
            velocity: phase == .began ? .zero : trail.speed(at: time),
            bounds: Rect(x: 0, y: 0, width: size.width, height: size.height))
        if phase == .ended || phase == .cancelled { self.from = nil }
    }

    /// What waits, taken: the frame asks the effect of it once.
    mutating func taken() -> PressInput? {
        defer { waiting = nil }
        return waiting
    }
}
