// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Pages and their arrangements on GTK: the chrome each page's header bar shows - its title or title view, its
/// actions, whether it offers the way back - and the user's choices handed to the host layer, which tells the pages
/// and the states.
/// Design: docs/design/platforms/gtk/pages.md
extension GTKElement {
    /// A page's children that furnish its header bar rather than stand in its room.
    static let slotTypes: Set<NodeType> = [.toolbarItems, .titleView, .menuBar, .contextMenu]

    /// What stands in a frame of its own, with a header bar: a page, and a tabbed view.
    static let framedTypes: Set<NodeType> = [.page, .tabbedView]

    /// The tab the user chose on a tabbed view, which the host layer shows.
    var chosenTab: Int? {
        (view as? GTKTabbedView)?.choice.chosen
    }

    /// Whether a split view's sidebar shows on screen.
    var showsSidebar: Bool? {
        (view as? GTKSplitView)?.isPresented
    }

    // MARK: - The header bar

    /// What a framed element's header bar shows. A page's own: its title or title view, its actions as the host layer
    /// orders them, whether its bar shows and whether it offers the way back. A tabbed view's: its switcher in the
    /// middle, over the chosen tab's page's actions.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    var chrome: GTKPageChrome {
        if type == .tabbedView {
            var chrome = element.selectedTab?.visiblePage?.gtk.chrome ?? GTKPageChrome()
            chrome.titleView = (view as? GTKTabbedView)?.switcher
            chrome.showsBar = value(.hasNavigationBar)?.bool != false
            chrome.offersBack = value(.hasBackButton)?.bool != false
            (chrome.barBackground, chrome.barForeground) = element.barColors
            return chrome
        }

        var chrome = GTKPageChrome()
        chrome.title = value(.title)?.string ?? ""
        chrome.titleView = element.slotContent(.titleView)?.gtk.view
        chrome.showsBar = value(.hasNavigationBar)?.bool != false
        chrome.offersBack = value(.hasBackButton)?.bool != false
        (chrome.barBackground, chrome.barForeground) = element.barColors

        let actions = element.chromeActions
        chrome.actions = actions.primary.map(Self.action)
        chrome.overflow = actions.overflow.map(Self.action)
        return chrome
    }

    /// A page's action as a button of its header bar.
    private static func action(_ item: MountedElement) -> GTKToolbarAction {
        GTKToolbarAction(
            title: item.value(.text)?.string ?? "", icon: item.value(.icon)?.string,
            isEnabled: item.value(.isEnabled)?.bool ?? true,
            perform: { [weak item] in item?.gtk.send(.clicked, []) })
    }

    /// Writes each framed element's chrome on its header bar, through this arrangement and every one it holds;
    /// `sidebar` shows a split view's sidebar from the header bar of the page the user sees in its detail.
    func composeChrome(showingSidebar sidebar: (shows: Bool, toggle: () -> Void)? = nil) {
        switch type {
        case .navigationStack:
            guard let navigation = view as? GTKNavigationView else { return }
            for (index, (page, frame)) in zip(children, navigation.frames).enumerated() {
                var chrome = page.chrome
                if index == children.count - 1 { chrome.sidebar = sidebar }
                frame.show(chrome)
                navigation.describe(
                    frame, title: page.element.visiblePage?.value(.title)?.string ?? "", canPop: chrome.offersBack)
                page.composeChrome()
            }
        case .splitView:
            guard let split = view as? GTKSplitView else { return }
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
                    detail.composeChrome()
                } else {
                    detail.composeChrome(showingSidebar: showing)
                }
            }
        case .tabbedView:
            element.selectedTab?.gtk.composeChrome()
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
        case .tabbedView:
            guard let tabs = view as? GTKTabbedView else { return }
            tabs.show(children.map { $0.value(.title)?.string ?? "" }, requested: value(.currentPage)?.number.map { Int($0) })
            tabs.onSelection = { [weak self] previous, selected in self?.tabChosen(from: previous, to: selected) }
        case .splitView:
            guard let split = view as? GTKSplitView else { return }
            split.onPresentationChanged = { [weak self] presented in self?.sidebarChanged(to: presented) }
            if changed.contains(.isSidebarVisible) { split.present(value(.isSidebarVisible)?.bool == true) }
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

    /// Takes the visible stack's top page away as the user does; whether there was one to take.
    func goBack() -> Bool {
        guard let stack = element.visibleNavigationStack, stack.children.count > 1,
              let navigation = stack.gtk.view as? GTKNavigationView
        else { return false }

        return navigation.popByUser()
    }

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
