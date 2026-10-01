// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a page's chrome takes from the visible path, the same on every host: the declarations of the arrangements
/// around the page, from the outermost in, then those in the page's own tree.
/// Design: docs/design/host/pages.md#the-visible-path
extension MountedElement {
    /// The elements of `sought` this page's chrome takes, in the path's order, each with its level - 0 for the
    /// outermost arrangement's, the page's own last. A sheet and a split view's sidebar start a path of their own - a
    /// modal stack's root stands on the path around the stack - and a native collection's items belong to no page.
    public func declared(_ sought: NodeType) -> [(element: MountedElement, level: Int)] {
        let arrangements = arrangementsAround
        var found: [(element: MountedElement, level: Int)] = []
        for (level, arrangement) in arrangements.enumerated() {
            found += arrangement.slots.filter { $0.type == sought }.map { ($0, level) }
        }
        found += declarations(sought).map { ($0, arrangements.count) }
        return found
    }

    /// The arrangements around this element on its path, the outermost first: up to its window, a split view's
    /// sidebar and a sheet stopping at theirs.
    var arrangementsAround: [MountedElement] {
        arrangements(sidebarWearsItsSplitView: false)
    }

    /// The arrangements whose bar this element's bar wears, the outermost first: those around it on its path, and a
    /// sidebar's own split view, whose bar is both its panes'.
    /// Design: docs/design/host/pages.md#the-bar-a-path-declares
    var barArrangements: [MountedElement] {
        arrangements(sidebarWearsItsSplitView: true)
    }

    private func arrangements(sidebarWearsItsSplitView: Bool) -> [MountedElement] {
        var arrangements: [MountedElement] = []
        var (child, each) = (self, parent)
        while let element = each, element.type != .window {
            if element.type == .splitView, element.children.first === child {
                if sidebarWearsItsSplitView { arrangements.insert(element, at: 0) }
                break
            }
            if element.type == .modalStack, element.children.first !== child { break }
            if NodeType.pageTypes.contains(element.type) { arrangements.insert(element, at: 0) }
            (child, each) = (element, element.parent)
        }
        return arrangements
    }

    /// The elements of `sought` in this element's tree, in the tree's order, looking into none of them and into no
    /// collection's items.
    private func declarations(_ sought: NodeType) -> [MountedElement] {
        children.flatMap { child -> [MountedElement] in
            if child.type == sought { return [child] }
            if NodeType.slotTypes.contains(child.type) || child.type == .itemsView { return [] }
            return child.declarations(sought)
        }
    }
}
