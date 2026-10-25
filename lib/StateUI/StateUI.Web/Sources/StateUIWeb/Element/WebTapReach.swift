// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Whether a press on a view is still a tap, as the page tells its pointer: until it travels as far as a drag - by the
/// host layer's rule, a finger farther than a mouse or a pen - whether or not the view hears the drag. The page clicks
/// a press a finger slid off the view and lifted beside it; past its reach that click is no tap.
/// Design: docs/design/platforms/web/input.md#taps
struct WebTapReach {
    private var drag = DragRecognition(distance: WebPress.distance(for: .mouse))

    /// The pointer pressed, while one is.
    private var pointer: Int?

    /// Whether the press under way, or the one let go last, is still a tap.
    var isTap: Bool { !drag.isDragging }

    /// A pointer of `kind` went down at `point` on the page: a new press, a tap until it travels.
    mutating func down(_ id: Int, at point: Point, kind: WebPress.Pointer) {
        guard pointer == nil || pointer == id else { return }
        pointer = id
        drag = DragRecognition(distance: WebPress.distance(for: kind))
        drag.pressed(at: point)
    }

    /// The pressed pointer moved to `point`.
    mutating func moved(_ id: Int, to point: Point) {
        guard id == pointer else { return }
        _ = drag.moved(to: point)
    }

    /// The pressed pointer let go, or the page took it away.
    mutating func up(_ id: Int) {
        if id == pointer { pointer = nil }
    }
}
