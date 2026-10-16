// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How the hand takes one view of a layout engine by itself rather than moving the run.
///
///     .itemDrag(begins: .held)
///
/// Design: docs/design/views/layout-engine.md#one-view-in-the-hand
public enum ItemDragStart: Int32, Equatable, Sendable {
    /// A first move across the layout's axis: a card pulled up out of a deck that scrolls sideways. A first move
    /// along it moves the run.
    case across = 0

    /// A press standing still a long press's time, then any way: an icon lifted off a board of icons. A move before
    /// it moves the run.
    case held = 1
}

extension ItemDragStart: HostRepresentable {}
