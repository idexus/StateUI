// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Why a page tree is shown or hidden: a change of what an arrangement shows, a move on a stack, or its window's.
enum GTKPagePresentationReason {
    case appearance
    case navigation
    case window
}

/// Pages and their arrangements: what each shows, the phases its pages hear, and the chrome each page's header bar
/// shows - its title or title view, its actions, whether it offers the way back.
/// Design: docs/design/platforms/gtk/pages.md
extension GTKElement {
    /// A page's children that furnish its header bar rather than stand in its room.
    static let slotTypes: Set<NodeType> = [.toolbarItems, .titleView, .menuBar, .contextMenu]

    /// What stands in a frame of its own, with a header bar: a page, and a tabbed view.
    static let framedTypes: Set<NodeType> = [.page, .tabbedView]

    /// The page the user sees in this arrangement: a stack's top, the chosen tab's, a split view's detail's.
    var visiblePage: GTKElement? {
        switch type {
        case .page: self
        case .navigationStack: children.last?.visiblePage
        case .tabbedView: selectedTab?.visiblePage
        case .splitView: children.dropFirst().first?.visiblePage
        default: nil
        }
    }

    /// The stack surrounding the visible content, if this arrangement has one.
    var visibleNavigationStack: GTKElement? {
        switch type {
        case .navigationStack: self
        case .tabbedView: selectedTab?.visibleNavigationStack
        case .splitView: children.dropFirst().first?.visibleNavigationStack
        default: nil
        }
    }

    /// What this arrangement shows while it is shown itself: a stack's top page, the chosen tab, a split view's
    /// detail and - while it shows - its sidebar.
    var shownChildren: [GTKElement] {
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
    var selectedTab: GTKElement? {
        guard !children.isEmpty else { return nil }
        let chosen = (view as? GTKTabbedView)?.selectedIndex ?? Int(value(.currentPage)?.number ?? 0)
        return children[min(max(chosen, 0), children.count - 1)]
    }

    /// Whether a split view shows its sidebar, as it stands on screen.
    var sidebarIsVisible: Bool {
        (view as? GTKSplitView)?.isPresented ?? (value(.isSidebarVisible)?.bool == true)
    }

    // MARK: - The header bar

    /// What a framed element's header bar shows. A page's own: its title or title view, its actions in their
    /// priority's order with the overflow's apart, whether its bar shows and whether it offers the way back. A
    /// tabbed view's: its switcher in the middle, over the chosen tab's page's actions.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    var chrome: GTKPageChrome {
        if type == .tabbedView {
            var chrome = selectedTab?.visiblePage?.chrome ?? GTKPageChrome()
            chrome.titleView = (view as? GTKTabbedView)?.switcher
            chrome.showsBar = value(.hasNavigationBar)?.bool != false
            chrome.offersBack = value(.hasBackButton)?.bool != false
            (chrome.barBackground, chrome.barForeground) = barColors
            return chrome
        }

        var chrome = GTKPageChrome()
        chrome.title = value(.title)?.string ?? ""
        chrome.titleView = firstView(in: .titleView)
        chrome.showsBar = value(.hasNavigationBar)?.bool != false
        chrome.offersBack = value(.hasBackButton)?.bool != false
        (chrome.barBackground, chrome.barForeground) = barColors

        let items = children.first { $0.type == .toolbarItems }?.children.filter { $0.type == .toolbarItem } ?? []
        let ordered = items.enumerated().sorted {
            let left = $0.element.value(.priority)?.number ?? 0
            let right = $1.element.value(.priority)?.number ?? 0
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        for item in ordered {
            let action = GTKToolbarAction(
                title: item.value(.text)?.string ?? "", icon: item.value(.icon)?.string,
                isEnabled: item.value(.isEnabled)?.bool ?? true,
                perform: { [weak item] in item?.send(.clicked, []) })
            if item.value(.placement)?.enumeration == 2 { chrome.overflow.append(action) } else { chrome.actions.append(action) }
        }
        return chrome
    }

    /// The colours this element's bar is painted in: the nearest stack's or tabbed view's around it, itself
    /// included, and what stands on the bar in, the nearest stack's - else the window's title bar's, whose
    /// place on a desktop of header bars is every header bar no arrangement colours.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    private var barColors: (background: HostValue?, foreground: HostValue?) {
        var background: HostValue?
        var foreground: HostValue?
        var each: GTKElement? = self
        while let element = each, background == nil || foreground == nil {
            switch element.type {
            case .navigationStack:
                background = background ?? element.value(.barBackgroundColor)
                foreground = foreground ?? element.value(.barForegroundColor)
            case .tabbedView:
                background = background ?? element.value(.barBackgroundColor)
            case .window:
                let titleBar = element.children.first { $0.type == .titleBar }
                background = background ?? titleBar?.value(.background)
                foreground = foreground ?? titleBar?.value(.barForegroundColor)
            default:
                break
            }
            each = element.parent
        }
        return (background, foreground)
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
                navigation.describe(frame, title: page.visiblePage?.value(.title)?.string ?? "", canPop: chrome.offersBack)
                page.composeChrome()
            }
        case .splitView:
            guard let split = view as? GTKSplitView else { return }
            let shows = sidebarIsVisible
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
            selectedTab?.composeChrome()
        default:
            break
        }
    }

    /// The view of a slot's first child: a page's title view.
    func firstView(in slot: NodeType) -> GTKView? {
        children.first { $0.type == slot }?.children.lazy.compactMap(\.layoutItem).first?.view
    }

    // MARK: - A page's phases

    /// Shows or hides this page tree, each page hearing its phases in its turn.
    /// Design: docs/design/platforms/gtk/pages.md#a-pages-phases
    func setPagePresented(_ presented: Bool, reason: GTKPagePresentationReason) {
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
    func reconcilePresentation(from previous: [GTKElement]) {
        guard pagePresented else { return }
        let current = shownChildren
        let reason: GTKPagePresentationReason = type == .navigationStack ? .navigation : .appearance

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
        host?.pump.handlers.enqueuePhase(handler)
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
            tabs.onSelection = { [weak self] previous, selected in self?.selectTab(from: previous, to: selected) }
        case .splitView:
            guard let split = view as? GTKSplitView else { return }
            split.onPresentationChanged = { [weak self] presented in self?.sidebarChanged(to: presented) }
            if changed.contains(.isSidebarVisible) { split.present(value(.isSidebarVisible)?.bool == true) }
        default:
            break
        }
    }

    /// The user chose another tab: the pages hear it, then the state the selection carries, and the chrome follows
    /// what the user sees now whether or not the application renders again.
    private func selectTab(from previous: Int, to selected: Int) {
        guard children.indices.contains(selected) else { return }

        if pagePresented {
            if children.indices.contains(previous) { children[previous].setPagePresented(false, reason: .appearance) }
            children[selected].setPagePresented(true, reason: .appearance)
        }
        report(.currentPage, .currentPageChanged, .number(Double(selected)))
        host?.refreshChrome()
    }

    // MARK: - The way back, and the sidebar

    /// Takes the visible stack's top page away as the user does; whether there was one to take.
    func goBack() -> Bool {
        guard let stack = visibleNavigationStack, stack.children.count > 1,
              let navigation = stack.view as? GTKNavigationView
        else { return false }

        return navigation.popByUser()
    }

    /// The user took the stack's top pages away - the back button, the swipe, the keys: the path is told how long
    /// it is now.
    private func userPopped(remaining: Int) {
        guard type == .navigationStack, let handler = element.handler(.popped) else { return }
        host?.dispatch(handler, payload: [.number(Double(remaining - 1))])
    }

    /// The user showed or hid a split view's sidebar through a header bar's button.
    func changeSidebarVisibility(to presented: Bool) {
        guard type == .splitView, let split = view as? GTKSplitView, split.isPresented != presented else { return }

        split.present(presented)
        sidebarChanged(to: presented)
    }

    /// The sidebar showed or hid: its page hears it, and the state the binding carries.
    func sidebarChanged(to presented: Bool) {
        if pagePresented { children.first?.setPagePresented(presented, reason: .appearance) }
        report(.isSidebarVisible, .isSidebarVisibleChanged, .bool(presented))
        host?.refreshChrome()
    }
}
