// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How the hand takes one view of a motion layout by itself rather than moving its parameters.
///
///     .itemDrag(begins: .longPress)
///
/// Design: docs/design/views/motion-layout.md#one-view-in-the-hand
public enum ItemDragStart: Int32, Equatable, Sendable {
    /// A first move perpendicular to the layout's scrolling axis: a card pulled up out of a deck that scrolls
    /// sideways. A first move along it moves the parameters.
    case perpendicular = 0

    /// A press standing still a long press's time, then any way: an icon lifted off a board of icons. A move before
    /// it moves the parameters.
    case longPress = 1
}

extension ItemDragStart: HostRepresentable {}
