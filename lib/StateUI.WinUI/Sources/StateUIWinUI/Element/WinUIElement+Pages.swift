// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Why a page tree is shown or hidden: a change of what an arrangement shows, a move on a stack, or its window's.
enum WinUIPagePresentationReason {
    case appearance
    case navigation
    case window
}

/// Pages and their arrangements: what each shows, the phases its pages hear, and the parts of the window's chrome
/// the visible arrangement gives - its title, the way back, the page's actions, the sidebar's toggle, the tabs.
/// Design: docs/design/platforms/winui/pages.md
extension WinUIElement {
    /// The page the user sees in this arrangement: a stack's top, the selected tab, a split view's detail.
    var visiblePage: WinUIElement? {
        switch type {
        case .page: self
        case .navigationStack: children.last?.visiblePage
        case .tabbedView: selectedTab?.visiblePage
        case .splitView: children.dropFirst().first?.visiblePage
        default: nil
        }
    }

    /// The stack surrounding the visible content, if this arrangement has one.
    var visibleNavigationStack: WinUIElement? {
        switch type {
        case .navigationStack: self
        case .tabbedView: selectedTab?.visibleNavigationStack
        case .splitView: children.dropFirst().first?.visibleNavigationStack
        default: nil
        }
    }

    /// The first tabbed view on the visible page path.
    var visibleTabbedView: WinUIElement? {
        switch type {
        case .tabbedView: self
        case .navigationStack: children.last?.visibleTabbedView
        case .splitView: children.dropFirst().first?.visibleTabbedView
        default: nil
        }
    }

    /// The colour written for the bars over the visible content: its stack's, else its tabbed view's.
    var visibleBarBackground: HostValue? {
        visibleNavigationStack?.value(.barBackgroundColor) ?? visibleTabbedView?.value(.barBackgroundColor)
    }

    /// The colour written for what stands on those bars.
    var visibleBarForeground: HostValue? {
        visibleNavigationStack?.value(.barForegroundColor)
    }

    /// The way back the visible stack offers, while its top page can go back.
    var visibleBackAction: WinUIToolbarAction? {
        guard let navigation = visibleNavigationStack, navigation.children.count > 1,
              let top = navigation.children.last,
              top.value(.hasNavigationBar)?.bool != false, top.value(.hasBackButton)?.bool != false
        else { return nil }

        let previous = navigation.children[navigation.children.count - 2]
        return WinUIToolbarAction(
            title: previous.value(.backButtonTitle)?.string ?? "Back", isEnabled: true,
            perform: { [weak navigation] in navigation?.popNavigation() })
    }

    /// The visible page's actions: the primary ones, then those behind the overflow, each group by priority and
    /// then source order. A page that hides its navigation furniture puts none of them on the chrome.
    var visibleToolbarActions: (primary: [WinUIToolbarAction], overflow: [WinUIToolbarAction]) {
        guard let page = visiblePage, page.value(.hasNavigationBar)?.bool != false,
              let items = page.children.first(where: { $0.type == .toolbarItems })?.children
        else { return ([], []) }

        let ordered = items.filter { $0.type == .toolbarItem }.enumerated().sorted {
            let left = $0.element.value(.priority)?.number ?? 0
            let right = $1.element.value(.priority)?.number ?? 0
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        let actions = ordered.map { item in
            (overflows: item.value(.placement)?.enumeration == 2, action: WinUIToolbarAction(
                title: item.value(.text)?.string ?? "", isEnabled: item.value(.isEnabled)?.bool ?? true,
                perform: { [weak item] in item?.send(.clicked, []) }))
        }
        return (actions.filter { !$0.overflows }.map(\.action), actions.filter(\.overflows).map(\.action))
    }

    /// The view the visible page shows in place of its title.
    var visibleTitleView: WinUIView? {
        visiblePage?.firstView(in: .titleView)
    }

    /// The sidebar's toggle, where this arrangement is a split view.
    var visibleSidebarToggle: (() -> Void)? {
        guard type == .splitView else { return nil }
        return { [weak self] in
            guard let self else { return }
            changeSidebarVisibility(to: !sidebarIsVisible)
        }
    }

    /// The tabs the window shows - those of the tabbed view on the visible page path, where its tabs are the
    /// window's - and the split view whose detail they stand across, if any.
    var visibleWindowTabs: WinUIWindowTabs? {
        guard let tabbed = visibleTabbedView, let tabs = tabbed.view as? WinUITabbedView, tabs.tabsShownByWindow
        else { return nil }

        var ancestor = tabbed.parent
        while let node = ancestor, node.type != .splitView { ancestor = node.parent }
        return WinUIWindowTabs(
            titles: tabs.titles, selected: tabs.shownIndex,
            select: { [weak tabs] index in tabs?.selectByUser(index) },
            split: ancestor?.view as? WinUISplitView)
    }

    /// Tells each tabbed view on this page path that its tabs are the window's: the first tabbed view down any path
    /// of stacks and split view details - the row stands beside a sidebar, never over it. A tabbed view in a
    /// sidebar, a tab of another or inside content keeps its tabs on its own row.
    func markTabsShownByWindow() {
        switch type {
        case .tabbedView: (view as? WinUITabbedView)?.tabsShownByWindow = true
        case .navigationStack: children.forEach { $0.markTabsShownByWindow() }
        case .splitView: children.dropFirst().forEach { $0.markTabsShownByWindow() }
        default: break
        }
    }

    /// The view of a slot's first child: a page's title view, an authored title bar's content.
    func firstView(in slot: NodeType) -> WinUIView? {
        children.first { $0.type == slot }?.children.lazy.compactMap(\.layoutItem).first?.view
    }

    /// What this arrangement shows while it is shown itself: a stack's top page, the selected tab, a split view's
    /// detail and - while it shows - its sidebar.
    var shownChildren: [WinUIElement] {
        switch type {
        case .navigationStack:
            return children.last.map { [$0] } ?? []
        case .tabbedView:
            return selectedTab.map { [$0] } ?? []
        case .splitView:
            let detail = Array(children.dropFirst().prefix(1))
            return sidebarIsVisible ? detail + children.prefix(1) : detail
        default:
            return []
        }
    }

    /// The tab a tabbed view shows: the one the user chose, else the one the tree says.
    var selectedTab: WinUIElement? {
        guard !children.isEmpty else { return nil }
        let chosen = (view as? WinUITabbedView)?.selectedIndex ?? Int(value(.currentPage)?.number ?? 0)
        return children[min(max(chosen, 0), children.count - 1)]
    }

    /// Whether a split view shows its sidebar, as it stands on screen.
    var sidebarIsVisible: Bool {
        (view as? WinUISplitView)?.isPresented ?? (value(.isSidebarVisible)?.bool == true)
    }

    /// Shows or hides this page tree, each page hearing its phases in its turn.
    /// Design: docs/design/platforms/winui/pages.md#a-pages-phases
    func setPagePresented(_ presented: Bool, reason: WinUIPagePresentationReason) {
        guard NodeType.pageTypes.contains(type), pagePresented != presented else { return }
        pagePresented = presented

        switch type {
        case .page:
            if presented {
                announce(.appearing)
                if reason == .navigation { announce(.navigatedTo) }
            } else {
                if reason == .navigation { announce(.navigatingFrom) }
                announce(.disappearing)
                if reason == .navigation { announce(.navigatedFrom) }
            }
        case .navigationStack:
            children.last?.setPagePresented(
                presented, reason: reason == .window && presented ? .navigation : reason == .window ? .appearance : reason)
        case .tabbedView:
            selectedTab?.setPagePresented(presented, reason: .appearance)
        case .splitView:
            children.dropFirst().first?.setPagePresented(presented, reason: .appearance)
            if sidebarIsVisible { children.first?.setPagePresented(presented, reason: .appearance) }
        default:
            break
        }
    }

    /// Moves presentation after the arrangement changed - a push or a pop, another tab, the sidebar shown or
    /// hidden: what stopped showing leaves first, then what started showing arrives.
    func reconcilePresentation(from previous: [WinUIElement]) {
        guard pagePresented else { return }
        let current = shownChildren
        let reason: WinUIPagePresentationReason = type == .navigationStack ? .navigation : .appearance

        for child in previous where !current.contains(where: { $0 === child }) {
            child.setPagePresented(false, reason: reason)
        }
        for child in current where !previous.contains(where: { $0 === child }) {
            child.setPagePresented(true, reason: reason)
        }
    }

    /// Hands a page's phase to its handler, rendered before the next phase is heard.
    private func announce(_ event: Event) {
        guard let handler = element.handler(event) else { return }
        host?.runtime.pump.handlers.enqueuePhase(handler)
    }

    /// Keeps an arrangement's own parts with the tree: a tabbed view's row, a split view's sidebar.
    func arrangePages(changed: Set<Prop>) {
        switch type {
        case .tabbedView:
            guard let tabs = view as? WinUITabbedView else { return }
            tabs.show(children.map { $0.value(.title)?.string ?? "" }, requested: value(.currentPage)?.number.map { Int($0) })
            tabs.onSelection = { [weak self] previous, selected in self?.selectTab(from: previous, to: selected) }
        case .splitView:
            guard let split = view as? WinUISplitView else { return }
            // The split's first room is decided inside a layout pass, and said once the pass is over.
            split.onPresentationChanged = { [weak self] presented in
                WinUIDoorbell.afterPass { [weak self] in self?.sidebarChanged(to: presented) }
            }
            if changed.contains(.isSidebarVisible) { split.present(value(.isSidebarVisible)?.bool == true) }
        default:
            break
        }
    }

    /// The user chose another tab: the pages hear it, then the state the selection carries, and the window's chrome
    /// follows what the user sees now whether or not the application renders again.
    private func selectTab(from previous: Int, to selected: Int) {
        guard children.indices.contains(selected) else { return }

        if pagePresented {
            if children.indices.contains(previous) { children[previous].setPagePresented(false, reason: .appearance) }
            children[selected].setPagePresented(true, reason: .appearance)
        }
        report(.currentPage, .currentPageChanged, .number(Double(selected)))
        host?.refreshWindowChrome()
    }

    // MARK: - The way back

    /// The way back this arrangement offers the user, innermost first: a stack pops its top page; nil where there
    /// is none.
    var wayBack: (() -> Void)? {
        visibleBackAction?.perform
    }

    /// The stack's top page goes: the path is told it is one shorter.
    func popNavigation() {
        guard type == .navigationStack, children.count > 1, let handler = element.handler(.popped) else { return }
        host?.runtime.dispatch(handler, payload: [.number(Double(children.count - 2))])
    }

    /// The user showed or hid a split view's sidebar through the window's chrome.
    func changeSidebarVisibility(to presented: Bool) {
        guard type == .splitView, let split = view as? WinUISplitView, split.isPresented != presented else { return }

        split.present(presented)
        sidebarChanged(to: presented)
    }

    /// The sidebar showed or hid: its page hears it, and the state the binding carries.
    private func sidebarChanged(to presented: Bool) {
        if pagePresented { children.first?.setPagePresented(presented, reason: .appearance) }
        report(.isSidebarVisible, .isSidebarVisibleChanged, .bool(presented))
        host?.refreshWindowChrome()
    }
}
