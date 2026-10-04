// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What an arrangement of pages shows, the same on every host: a stack's top page, the chosen tab, a split view's
/// detail and, while it shows, its sidebar.
/// Design: docs/design/host/pages.md#the-page-path
extension MountedElement {
    /// The page the user sees in this arrangement: a stack's top, the chosen tab, a split view's detail.
    public var visiblePage: MountedElement? {
        switch type {
        case .page: self
        case .navigationStack: children.last?.visiblePage
        case .tabView: selectedTab?.visiblePage
        case .splitView: children.dropFirst().first?.visiblePage
        case .modalStack: children.first?.visiblePage
        default: nil
        }
    }

    /// The page whose title names the window while this arrangement shows: the visible page, but tabs on a stack are
    /// its last place and name the window by their own title, else by the page beneath - their pages name their tabs
    /// alone; nil for none.
    /// Design: docs/design/host/pages.md#the-windows-chrome
    public var titledPage: MountedElement? {
        switch type {
        case .page: return self
        case .navigationStack: return children.last?.titledPage
        case .splitView: return children.dropFirst().first?.titledPage
        case .modalStack: return children.first?.titledPage
        case .tabView:
            if let tab = selectedTab, tab.type != .page { return tab.titledPage }
            guard let stack = parent, stack.type == .navigationStack else { return selectedTab }
            if value(.title) != nil { return self }
            let place = stack.children.firstIndex { $0 === self } ?? 0
            return place > 0 ? stack.children[place - 1].titledPage : selectedTab
        default: return nil
        }
    }

    /// The stack around the visible page, where the path has one.
    public var visibleNavigationStack: MountedElement? {
        switch type {
        case .navigationStack: self
        case .tabView: selectedTab?.visibleNavigationStack
        case .splitView: children.dropFirst().first?.visibleNavigationStack
        case .modalStack: children.first?.visibleNavigationStack
        default: nil
        }
    }

    /// Whether the stack this element stands on shows its bar over it: over a page that keeps its bar, and over an
    /// arrangement only where the page it shows stands in no stack of its own - that stack's bar is the one.
    public var showsTheStacksBar: Bool {
        guard let page = visiblePage, page.value(.showsNavigationBar)?.bool != false else { return false }
        return type == .page || visibleNavigationStack == nil
    }

    /// The first tabbed view on the visible page path.
    public var visibleTabView: MountedElement? {
        switch type {
        case .tabView: self
        case .navigationStack: children.last?.visibleTabView
        case .splitView: children.dropFirst().first?.visibleTabView
        default: nil
        }
    }

    /// What this arrangement shows while it is shown itself: a stack's top page, the chosen tab, a split view's
    /// detail and - while it shows - its sidebar.
    public var shownChildren: [MountedElement] {
        switch type {
        case .navigationStack: children.last.map { [$0] } ?? []
        case .tabView: selectedTab.map { [$0] } ?? []
        case .splitView:
            Array(children.dropFirst().prefix(1)) + (sidebarIsVisible ? Array(children.prefix(1)) : [])
        default: []
        }
    }

    /// The tab a tabbed view shows: the one the user chose, else the one the tree says, within the tabs.
    public var selectedTab: MountedElement? {
        guard !children.isEmpty else { return nil }

        let chosen = native.chosenTab ?? Int(value(.selectedTab)?.number ?? 0)
        return children[min(max(chosen, 0), children.count - 1)]
    }

    /// Whether a split view shows its sidebar: as it stands on screen, else as the tree says.
    public var sidebarIsVisible: Bool {
        native.showsSidebar ?? (value(.showsSidebar)?.bool == true)
    }

    /// The visible stack whose top page can go back: more than one page, and a top showing its bar and its way back.
    public var visibleBackStack: MountedElement? {
        guard let stack = visibleNavigationStack, stack.children.count > 1, let top = stack.children.last,
              top.value(.showsNavigationBar)?.bool != false, top.value(.showsBackButton)?.bool != false
        else { return nil }

        return stack
    }

    /// Whether a tabbed view's tabs stand in its window's row: the first tabbed view down the window's stacks and
    /// split view details - never one in a sidebar, in a tab of another, in a sheet or in content. A split view's
    /// sidebar is its first child as written, which holds while the children are still being made.
    public var tabsStandInWindow: Bool {
        guard type == .tabView else { return false }

        var child = self
        while let parent = child.parent {
            switch parent.type {
            case .window: return true
            case .navigationStack: break
            case .splitView where parent.writingOrder[child.id] != 0: break
            default: return false
            }
            child = parent
        }
        return false
    }
}
