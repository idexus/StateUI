// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How far the hand travels for one unit of the value it moves.
///
///     .translation(.horizontal, unit: .points(90))       // ninety points a unit
///     .swipe(.horizontal, unit: .containerLength)        // the room's width a unit: a page
///     .translation(.horizontal, unit: .frontItem)        // as far as the view in front moves for a unit
///
/// Design: docs/design/views/interaction.md#the-unit
public enum InteractionUnit: Equatable, Sendable {
    /// So many points of the hand's way for one unit; above nought.
    case points(Double)

    /// The length of the room along the hand's way: a page a unit, however the room turns.
    case containerLength

    /// As far as the view drawn in front moves for one unit where the value stands, so the hand carries that view
    /// with it whatever size the room makes it. A motion layout measures it.
    case frontItem
}
