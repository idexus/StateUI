// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The actions a chrome shows, composed from the groups the visible path declares, the same on every host: each
/// edge's groups in reading order - a declaration and those joining it by id, one shared background - and the
/// actions placed behind the overflow.
/// Design: docs/design/host/pages.md#the-actions-of-a-path
@_spi(Host) @MainActor public struct ChromeActions {
    /// The groups at the bar's leading edge, in reading order.
    public private(set) var leading: [[MountedElement]] = []

    /// The groups at the bar's trailing edge, in reading order.
    public private(set) var trailing: [[MountedElement]] = []

    /// The actions behind the overflow, in the order composed.
    public private(set) var overflow: [MountedElement] = []

    /// The trailing actions in reading order, for a bar that draws no groups.
    public var primary: [MountedElement] { trailing.flatMap { $0 } }

    /// None.
    public init() {}

    /// The actions of `declared` - toolbar groups, each with its level on the path, the outermost 0.
    init(_ declared: [(element: MountedElement, level: Int)]) {
        let declarations = declared.enumerated().map { Declaration($1.element, level: $1.level, index: $0) }

        // A group joins the one of its id declared further out; the outermost heads it.
        // Design: docs/design/host/pages.md#the-actions-of-a-path
        var groups: [[Declaration]] = []
        var byId: [ElementId: Int] = [:]
        for declaration in declarations {
            let id = declaration.group.id
            if id.isManual, let at = byId[id] {
                groups[at].append(declaration)
            } else {
                if id.isManual { byId[id] = groups.count }
                groups.append([declaration])
            }
        }

        let placed = groups.map { members -> (head: Declaration, items: [Placed]) in
            let head = members[0]
            let items = members.sorted { $0.key(on: head.side) < $1.key(on: head.side) }.flatMap { member in
                member.group.children.filter { $0.type == .toolbarItem }.map { Placed(item: $0, from: member) }
            }
            return (head, items)
        }

        let composed = [ToolbarSide.leading, .trailing].flatMap { side in
            placed.filter { $0.head.side == side }.sorted { $0.head.key(on: side) < $1.head.key(on: side) }
        }
        let standing = Self.standing(composed.flatMap(\.items))

        for group in composed {
            let items = group.items.compactMap { standing[ObjectIdentifier($0.item)] }
            let onBar = items.filter { !$0.isOverflow }
            overflow += items.filter(\.isOverflow)
            guard !onBar.isEmpty else { continue }
            if group.head.side == .leading { leading.append(onBar) } else { trailing.append(onBar) }
        }
    }

    /// The item standing in each place: an item of an id declared further in stands in the place of the outermost
    /// of that id, which the others leave; an item of no id stands in its own.
    private static func standing(_ items: [Placed]) -> [ObjectIdentifier: MountedElement] {
        var outermost: [ElementId: Placed] = [:]
        var innermost: [ElementId: Placed] = [:]
        for placed in items where placed.item.id.isManual {
            let id = placed.item.id
            if outermost[id].map({ placed.depth < $0.depth }) ?? true { outermost[id] = placed }
            if innermost[id].map({ placed.depth > $0.depth }) ?? true { innermost[id] = placed }
        }

        var standing: [ObjectIdentifier: MountedElement] = [:]
        for placed in items {
            guard placed.item.id.isManual else {
                standing[ObjectIdentifier(placed.item)] = placed.item
                continue
            }
            guard outermost[placed.item.id]?.item === placed.item else { continue }
            standing[ObjectIdentifier(placed.item)] = innermost[placed.item.id]?.item
        }
        return standing
    }

    /// One toolbar group as the path declares it.
    @MainActor private struct Declaration {
        let group: MountedElement
        let level: Int
        let index: Int
        let order: Int
        let side: ToolbarSide

        init(_ group: MountedElement, level: Int, index: Int) {
            self.group = group
            self.level = level
            self.index = index
            order = Int(group.value(.order)?.number ?? 0)
            side = group.value(.side)?.enumeration.flatMap { ToolbarSide(rawValue: Int32($0)) } ?? .trailing
        }

        /// Where it stands at `side`: by its order, then the outer in place at the edge - first on the leading side,
        /// last on the trailing - then as declared.
        func key(on side: ToolbarSide) -> (Int, Int, Int) {
            (order, side == .leading ? level : -level, index)
        }
    }

    /// An item where a declaration puts it.
    @MainActor private struct Placed {
        let item: MountedElement
        let depth: (Int, Int)

        init(item: MountedElement, from declaration: Declaration) {
            self.item = item
            depth = (declaration.level, declaration.index)
        }
    }
}

extension MountedElement {
    /// Whether this action stands behind the overflow.
    fileprivate var isOverflow: Bool {
        value(.placement)?.enumeration == ToolbarItemPlacement.overflow.rawValue
    }
}
