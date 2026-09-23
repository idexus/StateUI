// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A flag set, its bits numbered by StateUI: append a flag, never insert one.
// Design: docs/design/types/vocabularies.md#flag-sets-carry-bits

/// Which way a swipe went, and which ways a view listens for.
public struct SwipeDirection: OptionSet, Sendable {
    /// The direction bits.
    public let rawValue: Int32

    /// From the raw bits. `.left`, `[.left, .right]` and `.all` are the ordinary
    /// way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// A swipe whose dominant movement goes towards the right edge.
    public static let right = SwipeDirection(rawValue: 1)

    /// A swipe whose dominant movement goes towards the left edge.
    public static let left = SwipeDirection(rawValue: 2)

    /// A swipe whose dominant movement goes towards the top edge.
    public static let up = SwipeDirection(rawValue: 4)

    /// A swipe whose dominant movement goes towards the bottom edge.
    public static let down = SwipeDirection(rawValue: 8)

    /// Every direction - what a view listens for unless it says otherwise.
    public static let all: SwipeDirection = [.left, .right, .up, .down]

    /// Whether this is one direction, what a swipe reports, rather than a set.
    var isOneDirection: Bool {
        switch self {
        case .left, .right, .up, .down: true
        default: false
        }
    }

    /// The one direction a swipe went, as the event reports it - and nil for
    /// a set of several, or for anything else.
    init?(_ value: PropValue?) {
        guard let value, let direction = SwipeDirection(propValue: value), direction.isOneDirection else {
            return nil
        }

        self = direction
    }
}

extension SwipeDirection: HostRepresentable {}
