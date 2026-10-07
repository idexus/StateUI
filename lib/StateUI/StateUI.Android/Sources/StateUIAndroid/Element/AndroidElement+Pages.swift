// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Pages and their arrangements: a stack's bar, a tabbed view's row and a split view's drawer kept with the tree, and
/// the user's choices on them handed to the host layer, which tells the pages and the states.
/// Design: docs/design/platforms/android/pages.md
extension AndroidElement {
    /// The tab the user chose on a tabbed view, which the host layer shows.
    var chosenTab: Int? {
        (view as? AndroidTabView)?.choice.chosen
    }

    /// Whether a split view's sidebar shows on screen.
    var showsSidebar: Bool? {
        (view as? AndroidSplitView)?.isPresented
    }

    /// Keeps an arrangement's own parts with the tree: a stack's bar, a tabbed view's row, a split view's sidebar.
    func arrangePages(changed: Set<Prop>) {
        switch type {
        case .navigationStack:
            refreshBar()
        case .tabView:
            refreshTabs()
        case .splitView:
            guard let split = view as? AndroidSplitView else { return }
            split.onScrimTapped = { [weak self] in self?.changeSidebarVisibility(to: false) }
            split.onAdapted = { [weak self] in self?.sidebarShown(true) }
            if changed.contains(.showsSidebar) { split.present(value(.showsSidebar)?.bool == true) }
            // The detail's bars show the sidebar's button: they are told once the split holds both its pages.
            children.dropFirst().first?.refreshBars()
        default:
            break
        }
        // What an arrangement declares of the bar reaches every bar under it.
        // Design: docs/design/platforms/android/pages.md#the-bar
        if type != .page, NodeType.pageTypes.contains(type), !changed.isDisjoint(with: Self.barValues) { refreshBars() }
    }

    /// What an arrangement declares of the bars under it.
    static let barValues: Set<Prop> = [.barBackgroundColor, .barForegroundColor, .barIcon, .barSubtitle, .barTitle]

    /// Shows on a tabbed view's row its tabs' titles and pictures, and the tab the tree chose.
    private func refreshTabs() {
        guard let tabs = view as? AndroidTabView else { return }

        var row = AndroidTabView.Row()
        row.tabs = children.map { tab in
            AndroidTabView.Tab(
                title: tab.value(.title)?.string ?? "",
                picture: tab.value(.icon)?.string.flatMap { $0.isEmpty ? nil : $0 })
        }
        let colors = element.barColors
        row.background = colors.background
        // Words on a written colour: white on a dark one, the text's own on a light one (`BandWords`); the chosen
        // tab's in the colour written for them.
        if let background = row.background, BandWords.light(on: background) == true {
            row.chosenColor = .color(red: 255, green: 255, blue: 255, alpha: 255)
            row.color = .color(red: 255, green: 255, blue: 255, alpha: 170)
        }
        if let written = colors.foreground { row.chosenColor = written }
        tabs.show(row, requested: value(.selectedTab)?.number.map { Int($0) })
        tabs.onSelection = { [weak self] previous, selected in self?.selectTab(from: previous, to: selected) }
    }

    /// The user chose another tab: the host layer tells the pages and the state; the stack around the tabs names
    /// the page the user sees now.
    private func selectTab(from previous: Int, to selected: Int) {
        host?.runtime.tabChosen(element, from: previous, to: selected)
        refreshStacksBar()
    }

    /// The bar of the stack this page or arrangement stands in shows again, and the system's back follows it.
    private func refreshStacksBar() {
        host?.refreshBack()

        var stack = parent
        while let each = stack, NodeType.pageTypes.contains(each.type), each.type != .navigationStack {
            stack = each.parent
        }
        stack?.refreshBar()
    }

    // MARK: - The way back

    /// The way back a sidebar offers before any other: where it slides over the page and shows, it closes.
    var drawerBack: (() -> Void)? {
        switch type {
        case .splitView:
            if let split = view as? AndroidSplitView, split.overlays, split.isPresented {
                return { [weak self] in self?.changeSidebarVisibility(to: false) }
            }
            return children.dropFirst().first?.drawerBack
        case .navigationStack: return children.last?.drawerBack
        case .tabView: return element.selectedTab?.android.drawerBack
        default: return nil
        }
    }

    /// The user showed or hid a split view's sidebar: it shows as they said, and the host layer tells its page and
    /// the state.
    func changeSidebarVisibility(to presented: Bool) {
        guard type == .splitView, let split = view as? AndroidSplitView, split.isPresented != presented else { return }

        split.present(presented)
        sidebarShown(presented)
    }

    /// The sidebar showed or hid: the host layer tells its page and the state.
    private func sidebarShown(_ presented: Bool) {
        host?.runtime.sidebarShown(element, presented)
        host?.refreshBack()
    }

    // MARK: - A stack's bar

    /// Shows on a stack's bar what its visible page says: the title - the page's the host layer names it by
    /// (`titledPage`), or the view standing in for it - the line under it and the colours its path declares, the way
    /// back or to the sidebar, the page's actions in their order, and the menus its path declares behind the overflow.
    /// Design: docs/design/platforms/android/pages.md#the-bar
    func refreshBar() {
        guard type == .navigationStack, let navigation = view as? AndroidNavigationView else { return }
        let page = element.visiblePage
        // No place at the leading edge beside the navigation button: those groups stand first.
        // Design: docs/design/platforms/android/pages.md#the-bar
        let actions = page?.chromeActions ?? ChromeActions()
        let groups = actions.leading + actions.trailing
        let onBar = groups.flatMap { $0 }
        let shown = onBar + actions.overflow
        let colors = page?.barColors ?? element.barColors

        var content = AndroidBarView.Content()
        content.title = element.titledPage?.value(.title)?.string ?? ""
        content.subtitle = (page ?? element).titleArea?.subtitle
        content.background = colors.background
        content.foreground = BandWords.color(on: colors.background, written: colors.foreground)
        content.actions = shown.enumerated().map { place, item in
            item.android.menuPlace = place
            var action = item.android.menuItem
            action.onBar = onBar.contains { $0 === item }
            action.withText = action.onBar && item.showsActionWords
            action.group = groups.firstIndex { $0.contains { $0 === item } } ?? groups.count
            return action
        }
        var items = shown
        content.menus = Self.menuEntries(page?.chromeMenus.menus ?? [], items: &items)
        if element.visibleBackStack === element {
            content.navigation = .back
        } else if let split = enclosingSplit, let sidebar = split.children.first,
                  (split.view as? AndroidSplitView)?.overlays == true {
            content.navigation = .sidebar(sidebar.value(.icon)?.string)
        }

        navigation.setShowsBar(element.children.last?.showsTheStacksBar ?? true)
        let bar = navigation.bar(taking: AndroidBarView.Words(on: colors.background))
        bar.show(content)
        bar.showTitleView(page?.chromeTitleView?.android.layoutItem?.view)
        bar.items = items
        bar.onMenuChose = { [weak bar] index in
            guard let bar, bar.items.indices.contains(index) else { return }
            bar.items[index].android.send(.clicked, [])
        }
        bar.onNavigation = { [weak self] in
            guard let self else { return }
            if content.navigation == .back {
                host?.goBack(.pop(element))
            } else {
                enclosingSplit?.changeSidebarVisibility(to: true)
            }
        }
    }

    /// Refreshes the bar of every stack and the row of every tabbed view in this arrangement of pages.
    func refreshBars() {
        guard NodeType.pageTypes.contains(type) else { return }

        if type == .tabView { refreshTabs() }
        refreshBar()
        children.forEach { $0.refreshBars() }
    }

    /// The split view whose detail this arrangement stands in, through any stack or tab on the way.
    private var enclosingSplit: AndroidElement? {
        var child: AndroidElement = self
        while let parent = child.parent {
            if parent.type == .splitView { return parent.children.first === child ? nil : parent }
            guard NodeType.pageTypes.contains(parent.type) else { return nil }
            child = parent
        }
        return nil
    }
}
