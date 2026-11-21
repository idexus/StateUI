// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/views/transitions.md#an-effect

/// How a view is drawn while it is absent, against how it stands: what its entry comes from, and what its exit goes
/// to. An effect is made of steps - faded out, moved, scaled, out of sight - combined in the order written.
///
///     .transition(.symmetric(.opacity.combined(with: .translation(y: 12))))
public struct TransitionEffect: Equatable, Sendable {
    /// One step of an effect.
    enum Step: Equatable, Sendable {
        case opacity
        case translation(x: Double, y: Double)
        case scale(Double)
        case outside(SwipeDirection)
    }

    /// The steps, in the order written.
    let steps: [Step]

    /// The view as it stands: no effect.
    public static let identity = TransitionEffect(steps: [])

    /// The view faded out wholly.
    public static let opacity = TransitionEffect(steps: [.opacity])

    /// The view moved from its place, in points.
    ///
    /// - Parameters:
    ///   - x: how far across, right for more.
    ///   - y: how far down.
    /// - Returns: the effect.
    public static func translation(x: Double = 0, y: Double = 0) -> TransitionEffect {
        guard x.isFinite, y.isFinite else {
            complain("A TransitionEffect's translation is no number: it moves nothing.")
            return .identity
        }
        return TransitionEffect(steps: [.translation(x: x, y: y)])
    }

    /// The view drawn `factor` times as large about its middle.
    ///
    /// - Parameter factor: how many times as large; nought and more.
    /// - Returns: the effect.
    public static func scale(_ factor: Double) -> TransitionEffect {
        guard factor.isFinite, factor >= 0 else {
            complain("A TransitionEffect's scale is no number of nought or more: it scales nothing.")
            return .identity
        }
        return TransitionEffect(steps: [.scale(factor)])
    }

    /// The view wholly out of sight, one way: moved until its far edge has passed the edge of what shows it - its
    /// layout where that clips its content, else the nearest scroller or page above.
    ///
    /// - Parameter direction: which way out.
    /// - Returns: the effect.
    public static func outside(_ direction: SwipeDirection) -> TransitionEffect {
        TransitionEffect(steps: [.outside(direction)])
    }

    /// This effect, then `other`: a move written after a scale is not scaled, and a scale written after a move
    /// scales the move with the view.
    ///
    /// - Parameter other: the effect that comes after.
    /// - Returns: the two as one.
    public func combined(with other: TransitionEffect) -> TransitionEffect {
        TransitionEffect(steps: steps + other.steps)
    }
}

/// An effect as a host draws it: the opacity it multiplies the view's by, how far it moves the view, how many
/// times as large it draws it, and the way out of sight, if any.
@_spi(Host) public struct HostTransitionEffect: Equatable, Sendable {
    /// What the view's opacity is multiplied by.
    public var opacity = 1.0

    /// How far the view is moved, across and down, in points.
    public var translation = Point(x: 0, y: 0)

    /// How many times as large the view is drawn about its middle.
    public var scale = 1.0

    /// The way the view stands wholly out of sight; nil where it stands in it.
    public var outside: SwipeDirection?

    /// Whether the effect changes nothing.
    public var isIdentity: Bool { self == HostTransitionEffect() }

    /// The five numbers the effect crosses as.
    var numbers: [Double] { [opacity, translation.x, translation.y, scale, Double(outside?.rawValue ?? 0)] }

    /// The effect that changes nothing.
    public init() {}

    /// The effect back from its five numbers; nil for anything else.
    init?(numbers: ArraySlice<Double>) {
        let numbers = Array(numbers)
        guard numbers.count == 5, numbers.allSatisfy(\.isFinite) else { return nil }

        opacity = numbers[0]
        translation = Point(x: numbers[1], y: numbers[2])
        scale = numbers[3]
        outside = SwipeDirection(rawValue: Int32(numbers[4]))
    }

    /// How far the effect moves a view standing at `place` in a room of `room`: its own move, and - where it says
    /// a way out - as far that way as takes the whole view past the room's edge. A room nobody said moves none
    /// that way.
    public func move(of place: Rect?, in room: LayoutSize?) -> Point {
        var moved = translation
        guard let outside, let place, let room else { return moved }
        switch outside {
        case .left: moved.x -= place.x + place.width
        case .right: moved.x += room.width - place.x
        case .up: moved.y -= place.y + place.height
        case .down: moved.y += room.height - place.y
        }
        return moved
    }
}

extension TransitionEffect {
    /// The steps folded into what a host draws, in their order: each move added as it is written, each scale
    /// scaling the view and the moves before it, the last way out standing.
    @_spi(Host) public var host: HostTransitionEffect {
        var folded = HostTransitionEffect()
        for step in steps {
            switch step {
            case .opacity:
                folded.opacity = 0
            case .translation(let x, let y):
                folded.translation = Point(x: folded.translation.x + x, y: folded.translation.y + y)
            case .scale(let factor):
                folded.scale *= factor
                folded.translation = Point(x: folded.translation.x * factor, y: folded.translation.y * factor)
            case .outside(let direction):
                folded.outside = direction
            }
        }
        return folded
    }

    /// The effect a host's numbers say, its steps in one order: faded, scaled, moved, out.
    init(_ host: HostTransitionEffect) {
        var steps: [Step] = []
        if host.opacity == 0 { steps.append(.opacity) }
        if host.scale != 1 { steps.append(.scale(host.scale)) }
        if host.translation != Point(x: 0, y: 0) { steps.append(.translation(x: host.translation.x, y: host.translation.y)) }
        if let outside = host.outside { steps.append(.outside(outside)) }
        self.init(steps: steps)
    }
}
