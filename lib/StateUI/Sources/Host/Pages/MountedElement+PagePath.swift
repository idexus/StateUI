// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an arrangement of pages shows, the same on every host: a stack's top page, the chosen tab, a split view's
/// detail and, while it shows, its sidebar.
/// Design: docs/design/host/pages.md#the-page-path
extension MountedElement {
    /// The page the user sees in this arrangement: a stack's top, the chosen tab, a split view's detail.
    public var visiblePage: MountedElement? {
        switch type {
        case .page: self
        case .navigationStack: children.last?.visiblePage
        case .tabbedView: selectedTab?.visiblePage
        case .splitView: children.dropFirst().first?.visiblePage
        default: nil
        }
    }

    /// The stack around the visible page, where the path has one.
    public var visibleNavigationStack: MountedElement? {
        switch type {
        case .navigationStack: self
        case .tabbedView: selectedTab?.visibleNavigationStack
        case .splitView: children.dropFirst().first?.visibleNavigationStack
        default: nil
        }
    }

    /// The first tabbed view on the visible page path.
    public var visibleTabbedView: MountedElement? {
        switch type {
        case .tabbedView: self
        case .navigationStack: children.last?.visibleTabbedView
        case .splitView: children.dropFirst().first?.visibleTabbedView
        default: nil
        }
    }

    /// What this arrangement shows while it is shown itself: a stack's top page, the chosen tab, a split view's
    /// detail and - while it shows - its sidebar.
    public var shownChildren: [MountedElement] {
        switch type {
        case .navigationStack: children.last.map { [$0] } ?? []
        case .tabbedView: selectedTab.map { [$0] } ?? []
        case .splitView:
            Array(children.dropFirst().prefix(1)) + (sidebarIsVisible ? Array(children.prefix(1)) : [])
        default: []
        }
    }

    /// The tab a tabbed view shows: the one the user chose, else the one the tree says, within the tabs.
    public var selectedTab: MountedElement? {
        guard !children.isEmpty else { return nil }

        let chosen = native.chosenTab ?? Int(value(.currentPage)?.number ?? 0)
        return children[min(max(chosen, 0), children.count - 1)]
    }

    /// Whether a split view shows its sidebar: as it stands on screen, else as the tree says.
    public var sidebarIsVisible: Bool {
        native.showsSidebar ?? (value(.isSidebarVisible)?.bool == true)
    }

    /// The visible stack whose top page can go back: more than one page, and a top showing its bar and its way back.
    public var visibleBackStack: MountedElement? {
        guard let stack = visibleNavigationStack, stack.children.count > 1, let top = stack.children.last,
              top.value(.hasNavigationBar)?.bool != false, top.value(.hasBackButton)?.bool != false
        else { return nil }

        return stack
    }

    /// Whether a tabbed view's tabs stand in its window's row: the first tabbed view down the window's stacks and
    /// split view details - never one in a sidebar, in a tab of another, in a sheet or in content.
    public var tabsStandInWindow: Bool {
        guard type == .tabbedView else { return false }

        var child = self
        while let parent = child.parent {
            switch parent.type {
            case .window: return true
            case .navigationStack: break
            case .splitView where parent.children.first !== child: break
            default: return false
            }
            child = parent
        }
        return false
    }
}
