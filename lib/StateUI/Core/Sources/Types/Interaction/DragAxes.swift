// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which ways the hand takes a view it drags by itself.
///
///     .interaction(.drag(.vertical, begins: .directional))
///
/// Design: docs/design/views/interaction.md#a-views-own-press-and-drag
public enum DragAxes: Equatable, Sendable {
    /// Across.
    case horizontal

    /// Up and down.
    case vertical

    /// Any way.
    case both
}
