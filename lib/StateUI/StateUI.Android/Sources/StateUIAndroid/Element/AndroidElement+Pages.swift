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
            split.onAdapted = { [weak self] in
                self?.sidebarShown(true)
                self?.refreshBars()
            }
            split.onPlaced = { [weak self] in self?.refreshBars() }
            if changed.contains(.showsSidebar) { split.present(value(.showsSidebar)?.bool == true) }
            groundSidebar()
            // The sidebar's bar, and the detail's bars showing the sidebar's toggle where it does not show beside
            // them: they are told once the split holds both its pages.
            refreshBars()
        default:
            break
        }
        // What an arrangement declares of the bar reaches every bar under it.
        // Design: docs/design/platforms/android/pages.md#the-bar
        if type != .page, NodeType.pageTypes.contains(type), !changed.isDisjoint(with: Self.barValues) { refreshBars() }
    }

    /// Stands a split view's sidebar on its materials - Android blurs nothing behind a view, so a blur stands as its
    /// color.
    func groundSidebar() {
        guard let split = view as? AndroidSplitView else { return }
        let color = { (over: Bool) in
            self.element.sidebarMaterial(over: over).painted.flatMap { HostBrush($0).firstColor }.flatMap(AndroidView.argb)
        }
        split.grounds = (color(false), color(true))
    }

    /// What an arrangement declares of the bars under it.
    static let barValues: Set<Prop> = [.barBackground, .barForegroundColor]

    /// Shows on a tabbed view's row its tabs' titles and pictures, and the tab the tree chose.
    private func refreshTabs() {
        guard let tabs = view as? AndroidTabView else { return }

        var row = AndroidTabView.Row()
        row.tabs = arranged.map { tab in
            AndroidTabView.Tab(
                title: tab.value(.title)?.string ?? "",
                picture: HostPicture(tab.value(.icon)))
        }
        let colors = element.barColors
        row.background = colors.background
        // Words on a written color: white on a dark one, the text's own on a light one (`BandWords`); the chosen
        // tab's in the color written for them.
        if let background = row.background, BandWords.light(on: background) == true {
            row.chosenColor = .color(red: 255, green: 255, blue: 255, alpha: 255)
            row.color = .color(red: 255, green: 255, blue: 255, alpha: 170)
        }
        if let written = colors.foreground { row.chosenColor = written }
        tabs.show(row, requested: value(.selectedTab)?.number.map { Int($0) })
        tabs.onSelection = { [weak self] previous, selected in self?.selectTab(from: previous, to: selected) }
    }

    /// The user chose another tab: the host layer tells the pages and the state, and shows the chrome again.
    private func selectTab(from previous: Int, to selected: Int) {
        host?.runtime.tabChosen(element, from: previous, to: selected)
    }

    // MARK: - The way back

    /// The way back a sidebar offers before any other: where it slides over the page and shows, it closes.
    var drawerBack: (() -> Void)? {
        switch type {
        case .splitView:
            if let split = view as? AndroidSplitView, split.overlays, split.isPresented {
                return { [weak self] in self?.changeSidebarVisibility(to: false) }
            }
            return arranged.dropFirst().first?.drawerBack
        case .navigationStack: return arranged.last?.drawerBack
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
        refreshBars()
    }

    /// The sidebar showed or hid: the host layer tells its page and the state.
    private func sidebarShown(_ presented: Bool) {
        host?.runtime.sidebarShown(element, presented)
        host?.refreshBack()
    }

    // MARK: - A stack's bar

    /// Shows on a stack's bar what its visible page says: the title - the page's the host layer names it by
    /// (`titledPage`), or the view standing in for it - the line under it and the colors its path declares, the way
    /// back or to the sidebar, the page's actions in their order, and the menus its path declares behind the overflow.
    /// Design: docs/design/platforms/android/pages.md#the-bar
    func refreshBar() {
        if type == .splitView { return refreshSidebarBar() }
        guard type == .navigationStack, let navigation = view as? AndroidNavigationView else { return }
        let page = element.visiblePage
        // No place at the leading edge beside the navigation button: those groups stand first.
        // Design: docs/design/platforms/android/pages.md#the-bar
        let actions = page?.chromeActions ?? ChromeActions()
        let groups = actions.start + actions.end
        let onBar = groups.flatMap { $0 }
        let shown = onBar + actions.overflow
        let colors = page?.barColors ?? element.barColors

        var content = AndroidBarView.Content()
        // A page showing no title leaves the bar's place for it empty; the window keeps its name.
        let titled = element.titledPage
        content.title = titled?.value(.showsTitle)?.bool == false ? nil : titled?.value(.title)?.string ?? ""
        content.subtitle = titled?.value(.showsTitle)?.bool == false ? nil : titled?.barSubtitle
        content.background = colors.background
        content.foreground = BandWords.color(on: colors.background, written: colors.foreground)
        // Each item's place - its menu item's id less one - in the order the bar's menu is written: an action, the
        // entries of a menu it opens there, and then the menus behind the overflow.
        var items: [MountedElement] = []
        var splits: [MountedElement] = []
        content.actions = shown.map { item in
            item.android.menuPlace = items.count
            items.append(item)
            var action = item.android.menuItem
            action.onBar = onBar.contains { $0 === item }
            action.withText = action.onBar && item.showsActionWords
            action.group = groups.firstIndex { $0.contains { $0 === item } } ?? groups.count
            // A bar's button holding a menu: on the bar, its menu where its click opens it, else its action there and
            // its menu behind the overflow; behind the overflow, a submenu of what it offers there.
            // Design: docs/design/platforms/android/pages.md#the-bar
            switch ButtonMenu.opening(of: item) {
            case .none: break
            case .click where action.onBar: action.entries = Self.menuEntries(ButtonMenu.entries(of: item), items: &items)
            case _ where !action.onBar: action.entries = Self.menuEntries(ButtonMenu.inOverflow(item), items: &items)
            default: splits.append(item)
            }
            return action
        }
        let splitMenus = splits.map { item in
            AndroidMenu.Entry.menu(
                item.value(.text)?.string ?? "", isEnabled: item.isEffectivelyEnabled,
                Self.menuEntries(ButtonMenu.entries(of: item), items: &items))
        }
        content.menus = splitMenus + Self.menuEntries(page?.chromeMenus.menus ?? [], items: &items)
        // The sidebar's toggle first while the sidebar does not stand beside the detail shown, then the way back -
        // where the split view offers the toggle.
        // Design: docs/design/platforms/android/pages.md#the-bar
        let way: AndroidBarView.Navigation =
            element.visibleBackStack === element ? .back : element.offersClose ? .close : .none
        if let split = enclosingSplit, !split.sidebarStandsBeside,
           split.element.offersSidebarToggle {
            content.navigation = .sidebar
            content.afterNavigation = way
        } else {
            content.navigation = way
        }

        navigation.setShowsBar(element.arrangedChildren.last?.showsTheStacksBar ?? true)
        let bar = navigation.bar(taking: AndroidBarView.Words(on: colors.background))
        bar.show(content)
        bar.showTitleView(page?.chromeTitleView?.android.layoutItem?.view)
        bar.items = items
        bar.onMenuChose = { [weak bar] index in
            guard let bar, bar.items.indices.contains(index) else { return }
            bar.items[index].android.choose()
        }
        bar.onNavigation = { [weak self] in self?.pressed(content.navigation) }
        bar.onAfterNavigation = { [weak self] in self?.pressed(content.afterNavigation) }
    }

    /// The user pressed a stack's bar's button doing `what`: going back, closing the sheet, or showing the sidebar.
    private func pressed(_ what: AndroidBarView.Navigation) {
        switch what {
        case .back: host?.goBack(.pop(element))
        case .close: if let way = element.closingItsSheet { host?.goBack(way) }
        case .sidebar:
            guard let split = enclosingSplit else { return }
            split.changeSidebarVisibility(to: (split.view as? AndroidSplitView)?.isPresented != true)
        case .none: break
        }
    }

    /// Shows on a split view's sidebar its own bar: the title area its page names the application with - its title,
    /// else the application's name, the line under it and its picture as the mark - in the colors its path declares,
    /// and at its end the toggle hiding the sidebar, where the split view offers it.
    /// Design: docs/design/platforms/android/pages.md#a-split-view
    private func refreshSidebarBar() {
        guard let split = view as? AndroidSplitView, let page = element.sidebarPage else { return }
        let area = page.titleArea(applicationName: host?.runtime.core.applicationName ?? "")
        let colors = page.barColors

        var content = AndroidBarView.Content()
        content.title = area.title ?? ""
        content.subtitle = area.subtitle
        content.mark = area.icon
        content.background = colors.background
        content.foreground = BandWords.color(on: colors.background, written: colors.foreground)
        content.endButton = element.offersSidebarToggle ? .sidebar : .none
        let bar = split.drawer.bar(taking: AndroidBarView.Words(on: colors.background))
        bar.show(content)
        bar.onEndButton = { [weak self] in self?.changeSidebarVisibility(to: false) }
    }

    /// Whether this split view's sidebar shows beside its detail, its toggle on its own bar.
    private var sidebarStandsBeside: Bool {
        (view as? AndroidSplitView).map { !$0.overlays && $0.isPresented } ?? false
    }

    /// Refreshes the bar of every stack and the row of every tabbed view in this arrangement of pages.
    func refreshBars() {
        guard NodeType.pageTypes.contains(type) else { return }

        if type == .tabView { refreshTabs() }
        refreshBar()
        arranged.forEach { $0.refreshBars() }
    }

    /// The split view whose detail this arrangement stands in, through any stack or tab on the way.
    private var enclosingSplit: AndroidElement? {
        var child: AndroidElement = self
        while let parent = child.element.placingParent?.android {
            if parent.type == .splitView { return parent.arranged.first === child ? nil : parent }
            guard NodeType.pageTypes.contains(parent.type) else { return nil }
            child = parent
        }
        return nil
    }
}
