// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How the entries stand in a collection that knows no groups and shares a grid's width equally among its columns:
/// whether each is a header or a footer, the columns it spans, and the room it keeps around it, which spaces the items
/// and makes each a column's width.
/// Design: docs/design/host/items.md#a-collection-without-groups
@_spi(Host) public struct ItemsPlacement: Equatable, Sendable {
    /// The room an entry keeps around it, in points: before it in the reading direction, above it, after it.
    public struct Room: Equatable, Sendable {
        /// The room before the entry, in the reading direction.
        public var leading = 0.0

        /// The room above the entry.
        public var top = 0.0

        /// The room after the entry, in the reading direction.
        public var trailing = 0.0

        /// A room of `leading`, `top` and `trailing` points.
        public init(leading: Double = 0, top: Double = 0, trailing: Double = 0) {
            self.leading = leading
            self.top = top
            self.trailing = trailing
        }
    }

    /// The grid's columns; one for a list or a row.
    public let columns: Int

    /// Whether each entry is a header or a footer, in the order the entries show.
    public private(set) var edges: [Bool] = []

    /// The columns each entry spans.
    public private(set) var spans: [Int] = []

    /// The room each entry keeps around it.
    public private(set) var rooms: [Room] = []

    /// How `entries` stand as `layout` says in `width` points. Where the collection lets an entry span columns, a
    /// header or a footer spans them all and a group's last item what its row has left, so a group starts a row;
    /// where it does not, every entry takes the next cell.
    public init(_ entries: ItemsEntries, layout: ItemsLayout, width: Double, spanning: Bool) {
        guard case .grid(let minimum, let spacing) = layout else {
            columns = 1
            let across = layout.isAcross
            let spacing = switch layout {
            case .list(let spacing), .row(let spacing), .grid(_, let spacing): spacing
            }
            for entry in Self.walk(entries) {
                let before = entry.edge || entry.place == 0 ? 0 : spacing
                add(entry.edge, span: 1, across ? Room(leading: before) : Room(top: before))
            }
            return
        }

        let columns = ItemsGrid.columns(width: width, minimumItemWidth: minimum, spacing: spacing)
        self.columns = columns
        let itemWidth = ItemsGrid.columnWidth(width: width, columns: columns, spacing: spacing)
        // A cell at `column`, `span` columns wide, in a row after the first or not: as wide as a column, and
        // `spacing` from the cell beside it.
        func cell(_ column: Int, span: Int, below: Bool) -> Room {
            let leading = Double(column) * spacing / Double(columns)
            let trailing = Double(span) * width / Double(columns) - leading - itemWidth
            return Room(leading: leading, top: below ? spacing : 0, trailing: trailing)
        }

        for (place, entry) in Self.walk(entries).enumerated() {
            if !spanning {
                add(entry.edge, span: 1, cell(place % columns, span: 1, below: place >= columns))
            } else if entry.edge {
                add(true, span: columns, Room())
            } else {
                let column = entry.place % columns
                let span = entry.place == entry.count - 1 ? columns - column : 1
                add(false, span: span, cell(column, span: span, below: entry.place >= columns))
            }
        }
    }

    private mutating func add(_ edge: Bool, span: Int, _ room: Room) {
        edges.append(edge)
        spans.append(span)
        rooms.append(room)
    }

    /// Every entry in the order it shows: whether it is a header or a footer, and an item's place among its group's
    /// items and their count.
    private static func walk(_ entries: ItemsEntries) -> [(edge: Bool, place: Int, count: Int)] {
        let edge = (edge: true, place: 0, count: 0)
        var all = entries.header == nil ? [] : [edge]
        for section in entries.sections {
            if section.header != nil { all.append(edge) }
            all += section.items.indices.map { (edge: false, place: $0, count: section.items.count) }
            if section.footer != nil { all.append(edge) }
        }
        if entries.footer != nil { all.append(edge) }
        return all
    }
}
