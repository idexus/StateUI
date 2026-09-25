// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a view heard of the user's input, as a host's toolkit tells it, in the contract's terms.
/// Design: docs/design/host/runtime.md#what-the-user-does-with-a-finger
@_spi(Host) public enum HeardInput: Equatable, Sendable {
    /// A tap: its place in a quick run of taps, from 1; 0 for a press assistive technology made.
    case tap(run: Int)

    /// The pointer over the view: the View tier's event, and where it is, in points of the view.
    case pointer(Event, Point)

    /// A press dragged: its phase, and how far it has moved since it began.
    case drag(GesturePhase, x: Double, y: Double)

    /// A pinch: its phase, its scale since the last step, and where, as shares of the view's size.
    case pinch(GesturePhase, scale: Double, at: Point)
}

/// What a view listens for of the user's input.
@_spi(Host) public struct Hearing: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32

    /// Makes a set from its bits.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Taps, counted in quick runs.
    public static let taps = Hearing(rawValue: 1 << 0)

    /// The pointer entering, moving, pressing, releasing and leaving.
    public static let pointer = Hearing(rawValue: 1 << 1)

    /// A press dragged.
    public static let drags = Hearing(rawValue: 1 << 2)

    /// A pinch.
    public static let pinches = Hearing(rawValue: 1 << 3)

    /// Each kind of input on its own.
    public static let kinds: [Hearing] = [.taps, .pointer, .drags, .pinches]
}

/// A pinch's steps: each step's scale since the last, of a pinch a toolkit tells as its whole scale.
@_spi(Host) public struct PinchStep: Sendable {
    private var last = 1.0

    /// A pinch not begun.
    public init() {}

    /// The scale since the last step of a pinch standing at `scale` in `phase`: 1 as it begins and ends.
    public mutating func step(_ phase: GesturePhase, scale: Double) -> Double {
        let step = phase == .running && last > 0 ? scale / last : 1
        last = phase == .running ? scale : 1
        return step
    }

    /// Where `point` stands as shares of a view `width` by `height`: its middle where there is no point or no size.
    public static func share(of point: Point?, width: Double, height: Double) -> Point {
        guard let point, width > 0, height > 0 else { return Point(x: 0.5, y: 0.5) }
        return Point(x: point.x / width, y: point.y / height)
    }
}
