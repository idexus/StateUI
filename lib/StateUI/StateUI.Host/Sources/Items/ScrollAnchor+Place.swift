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
}
