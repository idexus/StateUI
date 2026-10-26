// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One view the hand holds by itself over a phase layout, as `onItemDragged` is told it: whether the hand takes it,
/// moves it or lets it go, the item it shows, where the hand is, the room, and how long the hand has stood still.
///
///     .onItemDragged { drag in
///         if drag.phase == .began { lift(drag.item) }
///         if drag.at.x > drag.room.width - 24, drag.still >= .milliseconds(500) { turnTheBoard() }
///     }
public struct ItemDrag<Item> {
    /// Whether the hand takes the view, moves it or stands, or lets it go - or it was taken away.
    public let phase: GesturePhase

    /// The item whose view the hand holds.
    public let item: Item

    /// Where the hand is, in the room the arithmetic is handed.
    public let at: Point

    /// The room the arithmetic is handed.
    public let room: Rect

    /// How long the hand has stood still; nought as it moves.
    public let still: Duration
}

extension ItemDrag: Sendable where Item: Sendable {}

extension ItemDrag: Equatable where Item: Equatable {}
