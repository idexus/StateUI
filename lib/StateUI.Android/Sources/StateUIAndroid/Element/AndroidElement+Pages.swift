// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Why a page tree is shown or hidden: a change of what an arrangement shows, a move on a stack, or its window's.
enum AndroidPagePresentationReason {
    case appearance
    case navigation
    case window
}

/// Pages and their arrangements: what each shows, the phases its pages hear, a stack's bar, and the way back.
/// Design: docs/design/platforms/android/pages.md
extension AndroidElement {
    /// The elements a window, a stack, a set of tabs or a split view arranges as pages.
    static let pageTypes: Set<NodeType> = [.page, .navigationStack, .tabbedView, .splitView]

    /// A page's children that furnish it rather than stand in it.
    static let slotTypes: Set<NodeType> = [.toolbarItems, .titleView, .menuBar, .contextMenu]

    /// The page the user sees in this arrangement: a stack's top, the selected tab, a split view's detail.
    var visiblePage: AndroidElement? {
        switch type {
        case .page: self
        case .navigationStack: children.last?.visiblePage
        case .tabbedView: selectedTab?.visiblePage
        case .splitView: children.dropFirst().first?.visiblePage
        default: nil
        }
    }

    /// What this arrangement shows while it is shown itself: a stack's top page, the selected tab, a split view's
    /// detail and - while it shows - its sidebar.
    var shownChildren: [AndroidElement] {
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
    var selectedTab: AndroidElement? {
        guard !children.isEmpty else { return nil }
        let chosen = (view as? AndroidTabbedView)?.selectedIndex ?? Int(value(.currentPage)?.number ?? 0)
        return children[min(max(chosen, 0), children.count - 1)]
    }

    /// Whether a split view shows its sidebar, as it stands on screen.
    var sidebarIsVisible: Bool {
        (view as? AndroidSplitView)?.isPresented ?? (value(.isSidebarVisible)?.bool == true)
    }

    /// Shows or hides this page tree, each page hearing its phases once Android shows what the tree shows.
    /// Design: docs/design/platforms/android/pages.md#a-pages-phases
    func setPagePresented(_ presented: Bool, reason: AndroidPagePresentationReason) {
        guard Self.pageTypes.contains(type), pagePresented != presented else { return }
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
    func reconcilePresentation(from previous: [AndroidElement]) {
        guard pagePresented else { return }
        let current = shownChildren
        let reason: AndroidPagePresentationReason = type == .navigationStack ? .navigation : .appearance

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
        host?.enqueuePhase(handler)
    }

    /// Keeps an arrangement's own parts with the tree: a stack's bar, a tabbed view's row, a split view's sidebar.
    func arrangePages(changed: Set<Prop>) {
        switch type {
        case .navigationStack:
            refreshBar()
        case .tabbedView:
            refreshTabs()
        case .splitView:
            guard let split = view as? AndroidSplitView else { return }
            split.onScrimTapped = { [weak self] in self?.changeSidebarVisibility(to: false) }
            if changed.contains(.isSidebarVisible) { split.present(value(.isSidebarVisible)?.bool == true) }
            // The detail's bars show the sidebar's button: they are told once the split holds both its pages.
            children.dropFirst().first?.refreshBars()
        default:
            break
        }
    }

    /// Shows on a tabbed view's row its tabs' titles and pictures, and the tab the tree chose.
    private func refreshTabs() {
        guard let tabs = view as? AndroidTabbedView else { return }

        var row = AndroidTabbedView.Row()
        row.tabs = children.map { tab in
            AndroidTabbedView.Tab(
                title: tab.value(.title)?.string ?? "",
                picture: tab.value(.icon)?.string.flatMap { $0.isEmpty ? nil : $0 })
        }
        row.background = value(.barBackgroundColor)
        if let background = row.background?.color {
            // Words on a written colour: white on a dark one, the text's own on a light one.
            let light = 0.299 * Double(background.red) + 0.587 * Double(background.green)
                + 0.114 * Double(background.blue) > 150
            row.chosenColor = light ? nil : .color(red: 255, green: 255, blue: 255, alpha: 255)
            row.color = light ? nil : .color(red: 255, green: 255, blue: 255, alpha: 170)
        }
        tabs.show(row, requested: value(.currentPage)?.number.map { Int($0) })
        tabs.onSelection = { [weak self] previous, selected in self?.selectTab(from: previous, to: selected) }
    }

    /// The user chose another tab: the pages hear it, then the state the selection carries.
    private func selectTab(from previous: Int, to selected: Int) {
        guard children.indices.contains(selected) else { return }

        if pagePresented {
            if children.indices.contains(previous) { children[previous].setPagePresented(false, reason: .appearance) }
            children[selected].setPagePresented(true, reason: .appearance)
        }
        report(.currentPage, .currentPageChanged, .number(Double(selected)))
        host?.refreshBack()

        // The stack around the tabs names the page the user sees now.
        var stack = parent
        while let each = stack, Self.pageTypes.contains(each.type), each.type != .navigationStack { stack = each.parent }
        stack?.refreshBar()
    }

    // MARK: - The way back

    /// The way back this arrangement offers the user, innermost first: a sidebar over the page closes, a stack
    /// pops its top page; nil where there is none.
    var wayBack: (() -> Void)? {
        switch type {
        case .splitView:
            if let split = view as? AndroidSplitView, split.overlays, split.isPresented {
                return { [weak self] in self?.changeSidebarVisibility(to: false) }
            }
            return children.dropFirst().first?.wayBack
        case .navigationStack:
            if let inner = children.last?.wayBack { return inner }
            guard children.count > 1, children.last?.value(.hasBackButton)?.bool != false else { return nil }
            return { [weak self] in self?.popNavigation() }
        case .tabbedView:
            return selectedTab?.wayBack
        default:
            return nil
        }
    }

    /// The stack's top page goes: the path is told it is one shorter.
    func popNavigation() {
        guard type == .navigationStack, children.count > 1, let handler = element.handler(.popped) else { return }
        host?.dispatch(handler, payload: [.number(Double(children.count - 2))])
    }

    /// The user showed or hid a split view's sidebar: its pages hear it, and the state the binding carries.
    func changeSidebarVisibility(to presented: Bool) {
        guard type == .splitView, let split = view as? AndroidSplitView, split.isPresented != presented else { return }

        split.present(presented)
        if pagePresented { children.first?.setPagePresented(presented, reason: .appearance) }
        report(.isSidebarVisible, .isSidebarVisibleChanged, .bool(presented))
        host?.refreshBack()
    }

    // MARK: - A stack's bar

    /// Shows on a stack's bar what its visible page says: the title, the colours, the way back or to the
    /// sidebar, and the page's actions in their order.
    /// Design: docs/design/platforms/android/pages.md#the-bar
    func refreshBar() {
        guard type == .navigationStack, let navigation = view as? AndroidNavigationView else { return }
        let page = visiblePage
        let items = page?.children.first { $0.type == .toolbarItems }?.children.filter { $0.type == .toolbarItem } ?? []
        let ordered = items.enumerated().sorted {
            let left = $0.element.value(.priority)?.number ?? 0
            let right = $1.element.value(.priority)?.number ?? 0
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        let overflows = { (item: AndroidElement) in item.value(.placement)?.enumeration == 2 }
        let shown = ordered.filter { !overflows($0) } + ordered.filter(overflows)

        var content = AndroidBarView.Content()
        content.title = page?.value(.title)?.string ?? ""
        content.background = value(.barBackgroundColor)
        content.foreground = value(.barForegroundColor)
        content.actions = shown.map { item in
            AndroidBarView.Action(
                title: item.value(.text)?.string ?? "",
                picture: item.value(.icon)?.string.flatMap { $0.isEmpty ? nil : $0 },
                overflows: overflows(item),
                isEnabled: item.value(.isEnabled)?.bool ?? true)
        }
        if children.count > 1, children.last?.value(.hasBackButton)?.bool != false {
            content.navigation = .back
        } else if let split = enclosingSplit, let sidebar = split.children.first,
                  (split.view as? AndroidSplitView)?.overlays == true {
            content.navigation = .sidebar(sidebar.value(.icon)?.string)
        }

        navigation.setShowsBar(page?.value(.hasNavigationBar)?.bool != false)
        navigation.bar.show(content)
        navigation.bar.onAction = { index in
            guard shown.indices.contains(index) else { return }
            shown[index].send(.clicked, [])
        }
        navigation.bar.onNavigation = { [weak self] in
            guard let self else { return }
            if content.navigation == .back {
                popNavigation()
            } else {
                enclosingSplit?.changeSidebarVisibility(to: true)
            }
        }
    }

    /// Refreshes the bar of every stack in this arrangement of pages.
    func refreshBars() {
        guard Self.pageTypes.contains(type) else { return }

        refreshBar()
        children.forEach { $0.refreshBars() }
    }

    /// The split view whose detail this arrangement stands in, through any stack or tab on the way.
    private var enclosingSplit: AndroidElement? {
        var child: AndroidElement = self
        while let parent = child.parent {
            if parent.type == .splitView { return parent.children.first === child ? nil : parent }
            guard Self.pageTypes.contains(parent.type) else { return nil }
            child = parent
        }
        return nil
    }
}
