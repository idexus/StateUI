// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// When the hand takes a view it drags by itself, rather than whatever stands behind it.
///
///     .interaction(.drag(.both, begins: .longPress))
///
/// Design: docs/design/views/interaction.md#a-views-own-press-and-drag
public enum DragStart: Equatable, Sendable {
    /// As soon as the press moves along the drag's axes.
    case immediately

    /// Once the press has stood still a long press's time, then any way along the axes: an icon lifted off a board
    /// of icons. A move before it is left to what stands behind the view.
    case longPress

    /// Once its first move goes the drag's one axis more than across it: a card pulled up out of a deck that
    /// scrolls sideways. A first move across is left to what stands behind the view.
    case directional
}
