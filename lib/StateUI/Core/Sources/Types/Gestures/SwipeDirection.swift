// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, each member numbered as its bit in `SwipeDirections`.
// Design: docs/design/types/vocabularies.md#flag-sets-carry-bits

/// Which way a swipe went - what `onSwiped` hears.
///
///     .onSwiped { direction in
///         switch direction {
///         case .left: next()
///         case .right: back()
///         case .up, .down: break
///         }
///     }
public enum SwipeDirection: Int32, Sendable, CaseIterable {
    /// Its dominant movement went towards the right edge.
    case right = 1

    /// Towards the left edge.
    case left = 2

    /// Towards the top edge.
    case up = 4

    /// Towards the bottom edge.
    case down = 8
}

extension SwipeDirection: HostRepresentable {}
