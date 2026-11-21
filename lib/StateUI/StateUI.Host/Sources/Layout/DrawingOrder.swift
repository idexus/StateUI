// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The order a layout draws its children in, back to front, the same on every host.
/// Design: docs/design/host/layout.md#drawing-order
@_spi(Host) public enum DrawingOrder {
    /// `count` children back to front: those `placements` place by their z-index, the earlier first among equals,
    /// then those placed by none in their order - and last, in that order, those `inFront` says a shared entry
    /// carries.
    public static func of(_ count: Int, placedBy placements: [HostPlacement], inFront: (Int) -> Bool) -> [Int] {
        let placed = min(count, placements.count)
        let ranked = (0..<placed).sorted { one, other in
            placements[one].zIndex == placements[other].zIndex
                ? one < other : placements[one].zIndex < placements[other].zIndex
        } + Array(placed..<max(placed, count))
        return ranked.filter { !inFront($0) } + ranked.filter(inFront)
    }

    /// A layout's views back to front, by their place in `presented` - every view in the order it stands, by
    /// whether it is kept as it leaves: those it arranges as `of(_:placedBy:inFront:)` orders them, `placements`
    /// placing them in their order, each kept one after the view it stood after - and last, in that order, those
    /// `inFront` says a shared transition carries.
    /// Design: docs/design/host/layout.md#drawing-order
    public static func of(presented kept: [Bool], placedBy placements: [HostPlacement], inFront: (Int) -> Bool) -> [Int] {
        let arranged = kept.indices.filter { !kept[$0] }
        var order = of(arranged.count, placedBy: placements) { _ in false }.map { arranged[$0] }
        for index in kept.indices where kept[index] {
            let after = index == 0 ? nil : order.firstIndex(of: index - 1)
            order.insert(index, at: after.map { $0 + 1 } ?? 0)
        }
        return order.filter { !inFront($0) } + order.filter(inFront)
    }
}
