// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension ScrollAnchor {
    /// Where a scroller over `room`, standing at `now`, stands for an item from `start`, `length` long, to stand
    /// where the anchor says; nil where the anchor is nearest and the item stands wholly in view already. The
    /// scroller keeps the place within its reach.
    /// Design: docs/design/host/items.md#scrolling-to-an-item
    @_spi(Host) public func place(of start: Double, length: Double, in room: Double, at now: Double) -> Double? {
        switch self {
        case .start: return start
        case .center: return start + length / 2 - room / 2
        case .end: return start + length - room
        case .nearest:
            if start >= now, start + length <= now + room { return nil }
            return start < now ? start : start + length - room
        }
    }

    /// Where a scroller `side` long over `content`, `before` and `after` covered at its ends by the bars over it and
    /// standing at `now`, stands for an item from `start`, `length` long: the anchor's place in the room the bars
    /// leave, held within the scroller's reach; nil where the anchor is nearest and the item stands in view.
    /// Design: docs/design/host/items.md#scrolling-to-an-item
    @_spi(Host) public func offset(
        of start: Double, length: Double, side: Double, content: Double, before: Double, after: Double, at now: Double
    ) -> Double? {
        guard let place = place(of: start, length: length, in: side - before - after, at: now + before) else {
            return nil
        }
        return ValueArithmetic.clamped(place - before, lower: -before, upper: Swift.max(-before, content + after - side))
    }
}
