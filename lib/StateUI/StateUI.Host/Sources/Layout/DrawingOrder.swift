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
}
