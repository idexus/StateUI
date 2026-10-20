// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// How an ItemsView's entries stand in AndroidX's recycler, as the host layer places them in a collection without
/// groups (`ItemsPlacement`), in the relay's numbers: its shape, each entry's kind and columns, and its room in pixels.
/// Design: docs/design/platforms/android/items.md#the-layout
struct AndroidItemsPlacement: Equatable {
    /// The relay's shape: down, across, or in columns (`AndroidItemsShape`).
    let shape: Int32

    /// The grid's columns; one for a list or a row.
    let columns: Int

    /// Each entry's kind - an item, or a header or a footer (`AndroidItemKind`) - and columns, in the order the
    /// entries show.
    let kinds: [Int32]
    let spans: [Int32]

    /// Each entry's room around it - leading, top, trailing, bottom - in pixels.
    let insets: [Int32]

    /// How `entries` stand as `layout` says in `width` points, `density` pixels a point.
    init(_ entries: ItemsEntries, layout: ItemsLayout, width: Double, density: Double) {
        let placement = ItemsPlacement(entries, layout: layout, width: width, spanning: true)
        shape = switch layout {
        case .list: AndroidItemsShape.list.rawValue
        case .row: AndroidItemsShape.row.rawValue
        case .grid: AndroidItemsShape.grid.rawValue
        }
        columns = placement.columns
        kinds = placement.edges.map { ($0 ? AndroidItemKind.edge : .item).rawValue }
        spans = placement.spans.map { Int32($0) }
        insets = placement.rooms.flatMap { room in
            [room.start, room.top, room.end, 0].map { Int32(($0 * density).rounded()) }
        }
    }
}
