// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import WASILibc

/// The pointers pressed on one view, as the page tells them: one dragged by the host layer's rule, two pinched -
/// how far apart they are against how far they began its scale, their middle where - and a trackpad's pinch, which
/// the page tells as a wheel turned with a key, or as Safari's gesture.
/// Design: docs/design/platforms/web/input.md#a-press-dragged-and-a-pinch
struct WebPress {
    /// Where each pointer pressed on the view stands on the page, by its number.
    private var pressed: [Int: Point] = [:]

    private var drag = DragRecognition(distance: .radius(4))

    /// The pointer a drag follows, while one does.
    private var dragging: Int?

    /// How far apart the two pointers began, and the pinch's steps, while two pinch.
    private var pinchSpan: Double?
    private var steps = PinchStep()

    /// A trackpad's pinch under way, and its scale from 1.
    private var turning: Double?

    /// Whether the press the user lets go of last was dragged, so its click is no tap.
    private(set) var wasDragged = false

    /// How far a pointer of `kind` - 0 a mouse, 1 a pen, 2 a touch - moves before its press is a drag.
    static func distance(for kind: Int) -> DragRecognition.Distance {
        .radius(kind == 2 ? 10 : 4)
    }

    /// A pointer of `kind` went down at `point` on the page: the first a press that may become a drag; a second
    /// ends that drag and begins a pinch.
    mutating func down(_ id: Int, at point: Point, kind: Int, origin: Point, size: LayoutSize) -> [HeardInput] {
        pressed[id] = point
        guard pressed.count == 1 else { return pinchBegins(at: middle(origin, size)) }
        wasDragged = false
        drag = DragRecognition(distance: Self.distance(for: kind))
        drag.pressed(at: point)
        dragging = id
        return []
    }

    /// A pressed pointer moved to `point`: the drag's move, or the pinch's step, its middle `inView` of a view
    /// `size`, its corner at `origin` on the page.
    mutating func moved(_ id: Int, to point: Point, origin: Point, size: LayoutSize) -> [HeardInput] {
        guard pressed[id] != nil else { return [] }
        pressed[id] = point
        if let pinchSpan, pinchSpan > 0, let span = span {
            return [.pinch(.changed, scale: steps.step(.changed, scale: span / pinchSpan), at: middle(origin, size))]
        }
        guard id == dragging else { return [] }
        let heard = drag.moved(to: point)
        if drag.isDragging { wasDragged = true }
        return heard
    }

    /// A pressed pointer let go, or the page took it away: the drag's end, or the pinch's.
    mutating func up(_ id: Int, letGo: Bool, origin: Point, size: LayoutSize) -> [HeardInput] {
        guard pressed[id] != nil else { return [] }
        defer { pressed[id] = nil }
        if pinchSpan != nil {
            let at = middle(origin, size)
            pinchSpan = nil
            return [.pinch(letGo ? .ended : .cancelled, scale: steps.step(.ended, scale: 1), at: at)]
        }
        guard id == dragging else { return [] }
        dragging = nil
        return drag.ended(letGo: letGo).map { [$0] } ?? []
    }

    /// A trackpad's pinch moved by a wheel's turn `down`, or stands at Safari's `scale` from 1, at `point` in a view
    /// `size`: it begins with its first step.
    mutating func trackpad(scale next: Double, at point: Point, size: LayoutSize) -> [HeardInput] {
        guard pinchSpan == nil else { return [] }
        let at = PinchStep.share(of: point, width: size.width, height: size.height)
        var heard: [HeardInput] = []
        if turning == nil {
            turning = 1
            heard.append(.pinch(.began, scale: steps.step(.began, scale: 1), at: at))
        }
        turning = next
        heard.append(.pinch(.changed, scale: steps.step(.changed, scale: next), at: at))
        return heard
    }

    /// The scale a wheel's turn `down` brings a trackpad's pinch to.
    func wheeled(down: Double) -> Double {
        (turning ?? 1) * exp(-down / 100)
    }

    /// A trackpad's pinch ended - Safari said so, or the wheel stood still.
    mutating func trackpadEnded(at point: Point, size: LayoutSize) -> [HeardInput] {
        guard turning != nil else { return [] }
        turning = nil
        let at = PinchStep.share(of: point, width: size.width, height: size.height)
        return [.pinch(.ended, scale: steps.step(.ended, scale: 1), at: at)]
    }

    private mutating func pinchBegins(at middle: Point) -> [HeardInput] {
        guard pressed.count == 2, pinchSpan == nil, let span else { return [] }
        var heard: [HeardInput] = []
        if dragging != nil, let end = drag.ended(letGo: false) { heard.append(end) }
        dragging = nil
        pinchSpan = span
        heard.append(.pinch(.began, scale: steps.step(.began, scale: 1), at: middle))
        return heard
    }

    /// How far apart the first two pointers stand.
    private var span: Double? {
        let two = pressed.sorted { $0.key < $1.key }.prefix(2).map(\.value)
        guard two.count == 2 else { return nil }
        let (x, y) = (two[1].x - two[0].x, two[1].y - two[0].y)
        return (x * x + y * y).squareRoot()
    }

    /// The first two pointers' middle, as shares of a view `size` whose corner stands at `origin` on the page.
    private func middle(_ origin: Point, _ size: LayoutSize) -> Point {
        let two = pressed.sorted { $0.key < $1.key }.prefix(2).map(\.value)
        guard two.count == 2 else { return Point(x: 0.5, y: 0.5) }
        let middle = Point(x: (two[0].x + two[1].x) / 2 - origin.x, y: (two[0].y + two[1].y) / 2 - origin.y)
        return PinchStep.share(of: middle, width: size.width, height: size.height)
    }
}
