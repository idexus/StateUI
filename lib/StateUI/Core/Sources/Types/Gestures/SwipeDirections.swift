// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A flag set, its bits numbered by StateUI: append a flag, never insert one.
// Design: docs/design/types/vocabularies.md#flag-sets-carry-bits

/// Which ways a view listens for a swipe.
///
///     Text("Card").onSwiped(directions: [.left, .right]) { direction in … }
public struct SwipeDirections: OptionSet, Sendable {
    /// The direction bits.
    public let rawValue: Int32

    /// From the raw bits. `.left`, `[.left, .right]` and `.all` are the ordinary
    /// way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// The one way `direction` goes.
    public init(_ direction: SwipeDirection) {
        self.init(rawValue: direction.rawValue)
    }

    /// A swipe towards the right edge.
    public static let right = SwipeDirections(.right)

    /// A swipe towards the left edge.
    public static let left = SwipeDirections(.left)

    /// A swipe towards the top edge.
    public static let up = SwipeDirections(.up)

    /// A swipe towards the bottom edge.
    public static let down = SwipeDirections(.down)

    /// Every direction - what a view listens for unless it says otherwise.
    public static let all: SwipeDirections = [.left, .right, .up, .down]

    /// Whether a swipe that went `direction` is one of these.
    public func contains(_ direction: SwipeDirection) -> Bool {
        contains(SwipeDirections(direction))
    }
}

extension SwipeDirections: HostRepresentable {}
