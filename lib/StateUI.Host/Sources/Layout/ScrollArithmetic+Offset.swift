// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where a scroller stands when the tree writes its offset, the same on every host.
/// Design: docs/design/host/layout.md#an-offset-the-tree-writes
extension ScrollArithmetic {
    /// What the tree's `offset` asks of a scroller standing at `standing` along `orientation`: the origin for one
    /// that scrolls neither way; nothing for no offset, one that is no number, or one it stands at already - the
    /// user's own scrolling coming back as the state it wrote; else the offset.
    public static func offsetWritten(_ offset: Point?, standing: Point, orientation: ScrollOrientation) -> Point? {
        guard orientation != .neither else { return Point(x: 0, y: 0) }
        guard let offset, offset.x.isFinite, offset.y.isFinite, differs(offset, standing) else { return nil }
        return offset
    }

    /// `target` kept within what the scroller reaches: from its origin to `reach`.
    public static func kept(_ target: Point, reach: Point) -> Point {
        Point(x: min(max(target.x, 0), reach.x), y: min(max(target.y, 0), reach.y))
    }

    /// Whether two offsets stand half a point or more apart on either axis.
    public static func differs(_ one: Point, _ other: Point) -> Bool {
        abs(one.x - other.x) >= 0.5 || abs(one.y - other.y) >= 0.5
    }
}
