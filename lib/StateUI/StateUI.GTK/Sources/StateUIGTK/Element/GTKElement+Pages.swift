// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Pages and their arrangements on GTK: the chrome each page's header bar shows - its title or title view, its
/// actions, whether it offers the way back - and the user's choices handed to the host layer, which tells the pages
/// and the states.
/// Design: docs/design/platforms/gtk/pages.md
extension GTKElement {
    /// What stands in a frame of its own, with a header bar: a page, and a tabbed view.
    static let framedTypes: Set<NodeType> = [.page, .tabView]

    /// The tab the user chose on a tabbed view, which the host layer shows.
    var chosenTab: Int? {
        (view as? GTKTabView)?.choice.chosen
    }

    /// Whether a split view's sidebar shows on screen.
    var showsSidebar: Bool? {
        (view as? GTKSplitView)?.isPresented
    }

    // MARK: - The header bar

    /// What a framed element's header bar shows. A page's own: its title or title view, its actions as the host layer
    /// orders them, whether its bar shows and whether it offers the way back. A tabbed view's: the chosen tab's
    /// page's, named by the page that names the window (`titledPage`), its switcher beneath the bar.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    var chrome: GTKPageChrome {
        if type == .tabView {
            // Over a tab that is a stack the stack's page shows the bar, the tabs beneath it (`composeChrome`).
            guard element.showsTheStacksBar else {
                var chrome = GTKPageChrome()
                chrome.showsBar = false
                return chrome
            }
            var chrome = element.selectedTab?.visiblePage?.gtk.chrome ?? GTKPageChrome()
            chrome.title = element.titledPage?.value(.title)?.string
                ?? element.enclosing(type: .window)?.value(.title)?.string ?? ""
            chrome.tabs = (view as? GTKTabView)?.switcher
            chrome.showsBar = value(.showsNavigationBar)?.bool != false
            chrome.offersBack = value(.showsBackButton)?.bool != false
            (chrome.barBackground, chrome.barForeground) = element.barColors
            return chrome
        }

        var chrome = GTKPageChrome()
        chrome.title = value(.title)?.string ?? ""
        chrome.subtitle = element.titleArea?.subtitle
        chrome.titleView = element.chromeTitleView?.gtk.view
        chrome.showsBar = value(.showsNavigationBar)?.bool != false
        chrome.offersBack = value(.showsBackButton)?.bool != false
        (chrome.barBackground, chrome.barForeground) = element.barColors

        let actions = element.chromeActions
        chrome.leading = actions.leading.map { $0.map(GTKToolbarAction.init) }
        chrome.trailing = actions.trailing.map { $0.map(GTKToolbarAction.init) }
        chrome.overflow = actions.overflow.map(GTKToolbarAction.init)
        let menus = element.chromeMenus.menus
        chrome.mainMenu = menus.isEmpty ? nil : GTKMenu(menus)
        return chrome
    }

    /// Writes each framed element's chrome on its header bar, through this arrangement and every one it holds;
    /// `sidebar` shows a split view's sidebar, and `tabs` a tabbed view's switcher, from the header bar of the page the
    /// user sees in it.
    func composeChrome(showingSidebar sidebar: (shows: Bool, toggle: () -> Void)? = nil, tabs: GTKView? = nil) {
        switch type {
        case .navigationStack:
            guard let navigation = view as? GTKNavigationView else { return }
            for (index, (page, frame)) in zip(children, navigation.frames).enumerated() {
                var chrome = page.chrome
                if index == children.count - 1 {
                    chrome.sidebar = sidebar
                    if let tabs { chrome.tabs = tabs }
                }
                frame.show(chrome)
                navigation.describe(
                    frame, title: page.element.visiblePage?.value(.title)?.string ?? "", canPop: chrome.offersBack)
                page.composeChrome()
            }
        case .splitView:
            guard let split = view as? GTKSplitView else { return }
            // GTK blurs nothing inside a window: a blur stands as its colour.
            let colour = { (over: Bool) in
                self.element.sidebarMaterial(over: over).painted.flatMap { GTKBrush($0).firstColor }
            }
            split.grounds = (colour(false), colour(true))
            let shows = element.sidebarIsVisible
            let showing: (shows: Bool, toggle: () -> Void) = (shows, { [weak self] in
                self?.changeSidebarVisibility(to: !shows)
            })
            if let sidebar = children.first {
                split.sidebarFrame?.show(sidebar.chrome)
                sidebar.composeChrome()
            }
            if let detail = children.dropFirst().first {
                if let frame = split.detailFrame {
                    var chrome = detail.chrome
                    chrome.sidebar = showing
                    frame.show(chrome)
                    detail.composeChrome(showingSidebar: chrome.showsBar ? nil : showing)
                } else {
                    detail.composeChrome(showingSidebar: showing)
                }
            }
        case .tabView:
            let handsDown = !element.showsTheStacksBar
            element.selectedTab?.gtk.composeChrome(
                showingSidebar: handsDown ? sidebar : nil, tabs: handsDown ? (view as? GTKTabView)?.switcher : nil)
        default:
            break
        }
    }

    /// Keeps an arrangement's own parts with the tree: a stack hears the user take its top page away, a tabbed view
    /// names its tabs and hears the user choose one, a split view shows its sidebar as the tree says.
    func arrangePages(changed: Set<Prop>) {
        switch type {
        case .navigationStack:
            (view as? GTKNavigationView)?.onPopped = { [weak self] remaining in self?.userPopped(remaining: remaining) }
        case .tabView:
            guard let tabs = view as? GTKTabView else { return }
            tabs.show(children.map { $0.value(.title)?.string ?? "" }, requested: value(.selectedTab)?.number.map { Int($0) })
            tabs.onSelection = { [weak self] previous, selected in self?.tabChosen(from: previous, to: selected) }
        case .splitView:
            guard let split = view as? GTKSplitView else { return }
            split.onPresentationChanged = { [weak self] presented in self?.sidebarChanged(to: presented) }
            if changed.contains(.showsSidebar) { split.present(value(.showsSidebar)?.bool == true) }
        default:
            break
        }
    }

    /// The user chose another tab: the host layer tells the pages and the state, and the chrome follows what the user
    /// sees now whether or not the application renders again.
    private func tabChosen(from previous: Int, to selected: Int) {
        host?.runtime.tabChosen(element, from: previous, to: selected)
        host?.refreshChrome()
    }

    // MARK: - The way back, and the sidebar

    /// The user took the stack's top pages away - the back button, the swipe, the keys: the path is told how long
    /// it is now.
    private func userPopped(remaining: Int) {
        guard type == .navigationStack, let handler = element.handler(.popped) else { return }
        host?.runtime.dispatch(handler, payload: [.number(Double(remaining - 1))])
    }

    /// The user showed or hid a split view's sidebar through a header bar's button.
    func changeSidebarVisibility(to presented: Bool) {
        guard type == .splitView, let split = view as? GTKSplitView, split.isPresented != presented else { return }

        split.present(presented)
        sidebarChanged(to: presented)
    }

    /// The sidebar showed or hid: the host layer tells its page and the state, and the chrome follows.
    func sidebarChanged(to presented: Bool) {
        host?.runtime.sidebarShown(element, presented)
        host?.refreshChrome()
    }
}
