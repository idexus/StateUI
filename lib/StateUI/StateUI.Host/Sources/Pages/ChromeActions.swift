// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The actions a chrome shows, the same on every host: the groups standing on its page's bar - or on the part of its
/// split view's one bar the page stands under - each at its position in reading order, one group one shared
/// background, and the overflow's sections.
/// Design: docs/design/host/pages.md#a-pages-actions
@_spi(Host) @MainActor public struct ChromeActions {
    /// The groups at the bar's start, in reading order.
    public private(set) var start: [[MountedElement]] = []

    /// The groups at the bar's end, in reading order.
    public private(set) var end: [[MountedElement]] = []

    /// The groups behind the overflow, each a section of it, in reading order.
    public private(set) var overflowSections: [[MountedElement]] = []

    /// The actions behind the overflow, in reading order.
    public var overflow: [MountedElement] { overflowSections.flatMap { $0 } }

    /// The actions at the end in reading order, for a bar that draws no groups.
    public var primary: [MountedElement] { end.flatMap { $0 } }

    /// None.
    public init() {}

    /// The actions of `declared` standing in `part` of a split view's bar - all of them where it is nil, a page off
    /// any split view - its sidebar shown on screen or not.
    init(_ declared: [Declared], part: ToolbarPart?, sidebarShown: Bool) {
        var placed: [(group: Declared, position: ToolbarPosition, index: Int)] = []
        for (index, group) in declared.enumerated() {
            guard var position = group.position else { continue }
            if let part {
                var stands = group.part
                // The sidebar's part not shown: its groups stand at the start of the detail's, or hide with it.
                if stands == .sidebar, !sidebarShown {
                    if group.hidesWithSidebar { continue }
                    (stands, position) = (.detail, position == .overflow ? .overflow : .start)
                }
                guard stands == part else { continue }
            }
            placed.append((group, position, index))
        }

        for position in [ToolbarPosition.start, .end, .overflow] {
            let outerFirst = position != .end
            // By order, then the outer at the edge - first at the start, last at the end - then as declared.
            let key = { (each: (group: Declared, position: ToolbarPosition, index: Int)) in
                (each.group.order, outerFirst ? each.group.depth : -each.group.depth, each.index)
            }
            let standing = placed.filter { $0.position == position }.sorted { key($0) < key($1) }
            for each in standing {
                let items = each.group.element.children.filter { [.toolbarButton, .toolbarToggle].contains($0.type) }
                guard !items.isEmpty else { continue }
                switch position {
                case .start: start.append(items)
                case .end: end.append(items)
                case .overflow: overflowSections.append(items)
                }
            }
        }
    }

    /// A toolbar group as its declarer declares it.
    @MainActor struct Declared {
        let element: MountedElement

        /// How far out its declarer stands: -1 for a split view's own, else how deep in its page's tree it stands.
        let depth: Int

        /// The part it stands in: its own, else its declarer's.
        let part: ToolbarPart

        let order: Int
        let hidesWithSidebar: Bool

        /// Where on the bar it stands; nil for a position no host knows.
        let position: ToolbarPosition?

        init(_ element: MountedElement, depth: Int, declarersPart: ToolbarPart) {
            self.element = element
            self.depth = depth
            part = element.value(.part)?.enumeration.flatMap { ToolbarPart(rawValue: Int32($0)) } ?? declarersPart
            order = Int(element.value(.order)?.number ?? 0)
            hidesWithSidebar = element.value(.hidesWithSidebar)?.bool ?? false
            position = element.value(.position)?.enumeration.map { ToolbarPosition(rawValue: Int32($0)) } ?? .end
        }
    }
}
