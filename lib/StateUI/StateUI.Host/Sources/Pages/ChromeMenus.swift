// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The menus a menu bar shows, composed from the menu bars the visible path declares, the same on every host: each
/// menu with the menus joining it by id, a section each after those declared around them, and an entry of an id
/// standing in the place of the one declared around it.
/// Design: docs/design/host/pages.md#the-menus-of-a-path
@_spi(Host) @MainActor public struct ChromeMenus {
    /// The menus in order, each a submenu entry holding what is composed in it.
    public private(set) var menus: [MenuEntry] = []

    /// None.
    public init() {}

    /// The menus of `declared` - menu bars, each with its level on the path, the outermost 0.
    init(_ declared: [(element: MountedElement, level: Int)]) {
        // A menu joins the one of its id declared further out; the outermost heads it.
        // Design: docs/design/host/pages.md#the-menus-of-a-path
        var joined: [[Placed]] = []
        var byId: [ElementID: Int] = [:]
        for (index, declaration) in declared.enumerated() {
            let order = Int(declaration.element.value(.order)?.number ?? 0)
            for (position, menu) in declaration.element.children.filter({ $0.type == .menu }).enumerated() {
                let placed = Placed(menu: menu, key: (order, declaration.level, index, position))
                if menu.id.isManual, let at = byId[menu.id] {
                    joined[at].append(placed)
                } else {
                    if menu.id.isManual { byId[menu.id] = joined.count }
                    joined.append([placed])
                }
            }
        }

        menus = joined.sorted { $0[0].key < $1[0].key }.map { members in
            let sections = Self.standing(members.sorted { $0.key < $1.key })
            let entries = sections.filter { !$0.isEmpty }.enumerated().flatMap { index, section in
                index == 0 ? section : [MenuEntry.separator] + section
            }
            return MenuEntry(menu: members[0].menu, entries: entries)
        }
    }

    /// Each member's entries as its section: an entry of an id declared further in stands in the place of the
    /// outermost of that id, which the others leave; an entry of no id stands in its own.
    private static func standing(_ members: [Placed]) -> [[MenuEntry]] {
        let sections = members.map { (member: $0, entries: MenuEntry.entries(of: $0.menu)) }
        var outermost: [ElementID: (Int, Int)] = [:]
        var innermost: [ElementID: (depth: (Int, Int), entry: MenuEntry)] = [:]
        for (member, entries) in sections {
            for entry in entries {
                guard let id = entry.element?.id, id.isManual else { continue }
                if outermost[id].map({ member.depth < $0 }) ?? true { outermost[id] = member.depth }
                if innermost[id].map({ member.depth > $0.depth }) ?? true { innermost[id] = (member.depth, entry) }
            }
        }

        return sections.map { member, entries in
            entries.compactMap { entry in
                guard let id = entry.element?.id, id.isManual else { return entry }
                guard outermost[id].map({ $0 == member.depth }) ?? false else { return nil }
                return innermost[id]?.entry
            }
        }
    }

    /// A menu where a declaration puts it.
    @MainActor private struct Placed {
        let menu: MountedElement

        /// By the declaration's order, then the outer first, then as declared.
        let key: (Int, Int, Int, Int)

        /// How far in its declaration stands: its level, then its place on the path.
        var depth: (Int, Int) { (key.1, key.2) }
    }
}
