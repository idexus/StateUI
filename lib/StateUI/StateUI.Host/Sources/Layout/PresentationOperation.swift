// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A finite operation on one element's own presentation, with one end: where its effect leads, a hand taking the
/// view again, or the view leaving. It moves nothing the application wrote; the element keeps its place.
/// Design: docs/design/host/interaction.md#a-view-thrown-away
@_spi(Host) public struct PresentationOperation: Equatable, Sendable {
    /// What the operation does to the view.
    public enum Effect: Equatable, Sendable {
        /// The view leaves the room that holds it one way, wholly.
        case outside(SwipeDirection)
    }

    /// How an operation ends, once.
    public enum Result: Equatable, Sendable {
        /// It came where its effect leads.
        case finished
        /// A hand took the view on its way.
        case interrupted
        /// The view, or the room it stood in, went first.
        case cancelled
        /// The budget of views kept as they leave ended it: too many at once, or too long.
        case limited
        /// A message made again what the tree showed.
        case detached
    }

    /// What it does.
    public let effect: Effect

    /// How fast the view goes, in points a second.
    public let velocity: Point

    /// How far the view stands from its place.
    public private(set) var offset: Point

    /// When it was last stepped, in milliseconds, and when it ends whatever it met.
    private var stepped: Double
    private let latest: Double

    /// The operation `effect` begun at `now` on a view standing `offset` from its place, the hand letting it go at
    /// `speed`: its way out is no slower than `room`'s length in `pace` milliseconds, so it ends.
    public init(
        _ effect: Effect, from offset: Point, speed: Point, pace: Double, room: LayoutSize, at now: Double
    ) {
        self.effect = effect
        self.offset = offset
        stepped = now
        let length = max(pace, 1) / 1_000
        var velocity = speed
        switch effect {
        case .outside(.up): velocity.y = min(velocity.y, -room.height / length)
        case .outside(.down): velocity.y = max(velocity.y, room.height / length)
        case .outside(.left): velocity.x = min(velocity.x, -room.width / length)
        case .outside(.right): velocity.x = max(velocity.x, room.width / length)
        }
        self.velocity = velocity
        // A room nothing was laid out in gives no pace: the view is out once the pace has run twice.
        latest = now + max(pace, 1) * 2
    }

    /// A frame at `now`: the view goes on. Whether its `frame` in `room`, as far from its place as it now stands,
    /// has left the room wholly - or the operation has run as long as it may.
    public mutating func step(to now: Double, frame: Rect?, room: LayoutSize?) -> Bool {
        let seconds = max(now - stepped, 0) / 1_000
        stepped = now
        offset = Point(x: offset.x + velocity.x * seconds, y: offset.y + velocity.y * seconds)
        guard let frame, let room, room.width > 0, room.height > 0 else { return now >= latest }

        let (x, y) = (frame.x + offset.x, frame.y + offset.y)
        return x + frame.width <= 0 || y + frame.height <= 0 || x >= room.width || y >= room.height
    }
}
