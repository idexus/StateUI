// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view the user threw away: which way it left, and how fast the hand let it go.
///
///     Card(card)
///         .interaction(.drag(.vertical).dismissal(directions: .up, threshold: 120))
///         .onDismissed { dismissal in cards.removeAll { $0.id == card.id } }
///
/// Design: docs/design/views/interaction.md#a-view-thrown-away
public struct Dismissal: Equatable, Sendable {
    /// The way the view left.
    public var direction: SwipeDirection

    /// How fast the hand let it go, in points a second.
    public var velocity: Point

    /// One dismissal, from the two values the event carries: the way out and the hand's speed.
    init(direction: SwipeDirection, velocity: Point) {
        self.direction = direction
        self.velocity = velocity
    }
}
