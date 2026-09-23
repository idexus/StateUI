// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// Pages, tabs, split views, the window chrome they give, and menus.
extension AppKitElement {
    var pageView: NSView? {
        pageNode?.presentableViews.first
    }

    var presentablePageView: NSView? { presentableViews.first }

    var pageNode: AppKitElement? {
        children.first(where: { Self.pageTypes.contains($0.type) })
    }

    var modalStackNode: AppKitElement? {
        children.first { $0.type == .modalStack }
    }

    var overlayItem: AppKitLayoutItem? {
        slot(.overlay)?.children.first?.layoutItem
    }

    var visiblePage: AppKitElement? {
        switch type {
        case .page:
            return self
        case .navigationStack:
            return children.last?.visiblePage
        case .tabbedView:
            return selectedTab?.visiblePage
        case .splitView:
            return children.dropFirst().first?.visiblePage
        default:
            return pageNode?.visiblePage
        }
    }

    /// The native navigation container currently surrounding the visible
    /// content, if this page arrangement has one.
    var visibleNavigationStack: AppKitElement? {
        switch type {
        case .navigationStack:
            return self
        case .tabbedView:
            return selectedTab?.visibleNavigationStack
        case .splitView:
            return children.dropFirst().first?.visibleNavigationStack
        default:
            return pageNode?.visibleNavigationStack
        }
    }

    /// The colour written for the bars over the visible content: its
    /// navigation stack's, else its tabbed view's.
    var visibleBarBackground: NSColor? {
        visibleNavigationStack?.color(.barBackgroundColor)
            ?? visibleTabbedView?.color(.barBackgroundColor)
    }

    /// The colour written for what stands on those bars.
    var visibleBarForeground: NSColor? {
        visibleNavigationStack?.color(.barForegroundColor)
    }

    /// The tabs the window shows beneath its toolbar - those of the tabbed
    /// view on the visible page path, where its tabs are the window's - and
    /// the split view whose detail it stands in, if any.
    var visibleWindowTabs: AppKitTabsPlacement? {
        guard let tabbed = visibleTabbedView,
              let tabs = tabbed.view as? AppKitTabbedView,
              tabs.tabsShownByWindow
        else { return nil }

        var ancestor = tabbed.parent
        while let node = ancestor, node.type != .splitView {
            ancestor = node.parent
        }

        let segments = tabs.segments
        return AppKitTabsPlacement(
            tabs: AppKitWindowTabs(
                titles: segments.map(\.title),
                images: segments.map(\.image),
                selected: tabs.selectedIndex,
                select: { [weak tabs] index in tabs?.selectByUser(index) }),
            split: ancestor?.view as? AppKitSplitView)
    }

    /// The first tabbed view on the visible page path.
    var visibleTabbedView: AppKitElement? {
        switch type {
        case .page:
            return nil
        case .tabbedView:
            return self
        case .navigationStack:
            return children.last?.visibleTabbedView
        case .splitView:
            return children.dropFirst().first?.visibleTabbedView
        default:
            return pageNode?.visibleTabbedView
        }
    }

    /// Tells each tabbed view on this page path that its tabs are the
    /// window's, in the row beneath its toolbar: the first tabbed view down
    /// any path of stacks and split view details - the row stands beside a
    /// sidebar, never over it. Asked of the window's page once the whole tree
    /// is arranged, so what stands where is the tree's final word. A tabbed
    /// view in a sidebar, a sheet, a tab of another or inside content is never
    /// told, and keeps its tabs on its own content.
    func markTabsShownByWindow() {
        switch type {
        case .tabbedView:
            (view as? AppKitTabbedView)?.tabsShownByWindow = true
        case .navigationStack:
            children.forEach { $0.markTabsShownByWindow() }
        case .splitView:
            children.dropFirst().forEach { $0.markTabsShownByWindow() }
        default:
            break
        }
    }

    /// The native split view controller of a split page.
    var sidebarController: NSSplitViewController? {
        (view as? AppKitSplitView)?.splitController
    }

    /// The way back the visible navigation stack offers, while its top page
    /// can go back.
    var visibleBackAction: AppKitToolbarAction? {
        guard let navigation = visibleNavigationStack,
              navigation.children.count > 1,
              let top = navigation.children.last,
              top.bool(.hasNavigationBar) ?? true,
              top.bool(.hasBackButton) ?? true
        else { return nil }

        let previous = navigation.children[navigation.children.count - 2]
        let title = previous.string(.backButtonTitle) ?? "Back"
        return AppKitToolbarAction(
            identifier: AppKitWindowToolbar.back,
            title: title,
            image: AppKitWindowToolbar.backImage,
            isEnabled: true,
            perform: { [weak navigation] in navigation?.popNavigation() })
    }

    /// The visible page's actions: the primary ones, then those behind
    /// native overflow, each group by priority and then source order. A page
    /// that hides its navigation furniture puts none of them in the toolbar.
    var visibleToolbarActions: (primary: [AppKitToolbarAction], overflow: [AppKitToolbarAction]) {
        guard let page = visiblePage,
              page.bool(.hasNavigationBar) ?? true,
              let items = page.slot(.toolbarItems)?.children
        else { return ([], []) }

        let ordered = items.enumerated().sorted {
            let left = $0.element.whole(.priority) ?? 0
            let right = $1.element.whole(.priority) ?? 0
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        let actions = ordered.map { item in
            (overflows: item.enumeration(.placement) == 2, action: AppKitToolbarAction(
                identifier: NSToolbarItem.Identifier("StateUI.action.\(item.mount)"),
                title: item.string(.text) ?? "",
                image: item.image(.icon),
                isEnabled: item.bool(.isEnabled) ?? true,
                perform: { [weak item] in item?.clicked(nil) }))
        }
        return (
            actions.filter { !$0.overflows }.map(\.action),
            actions.filter(\.overflows).map(\.action))
    }

    /// The view the visible page shows in place of its title.
    var visibleTitleView: NSView? {
        visiblePage?.slot(.titleView)?.presentableViews.first
    }

    var pageMenuItems: [NSMenuItem] {
        visiblePage?.slot(.menuBar)?.children.compactMap { $0.nativeMenuItem } ?? []
    }

    /// Makes this page tree visible or hidden, reporting phases only after the
    /// native tree has reached the same state.
    func setPagePresented(_ presented: Bool, reason: AppKitPagePresentationReason) {
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
                presented,
                reason: reason == .window && presented ? .navigation
                    : (reason == .window ? .appearance : reason))

        case .tabbedView:
            selectedTab?.setPagePresented(presented, reason: .appearance)

        case .splitView:
            children.dropFirst().first?.setPagePresented(presented, reason: .appearance)
            if sidebarIsVisible {
                children.first?.setPagePresented(presented, reason: .appearance)
            }

        default:
            break
        }
    }

    func announce(_ event: Event) {
        guard let handler = events[event] else { return }
        host?.enqueue(handler, isPhase: true)
    }

    /// What this arrangement shows while it is shown itself: a stack's top
    /// page, a tabbed view's selected tab, a split view's detail and - while
    /// it shows - its sidebar. Nothing, for anything else.
    var shownChildren: [AppKitElement] {
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

    /// Moves presentation to follow a change of the arrangement - a push or a
    /// pop, another tab, the sidebar showing or hiding, or a shown child
    /// replaced outright: what stopped showing leaves first, then what started
    /// showing arrives. On a stack that is a navigation; anywhere else it is a
    /// change of what is visible.
    func reconcilePresentation(from previous: [AppKitElement]) {
        guard pagePresented else { return }
        let current = shownChildren
        let reason: AppKitPagePresentationReason =
            type == .navigationStack ? .navigation : .appearance

        for child in previous where !current.contains(where: { $0 === child }) {
            child.setPagePresented(false, reason: reason)
        }
        for child in current where !previous.contains(where: { $0 === child }) {
            child.setPagePresented(true, reason: reason)
        }
    }

    /// Reports the tab a tabbed view fell back to when its selected tab went
    /// away.
    func reportTabFallback() {
        if let fallback = pendingTabFallback,
           let handler = events[.currentPageChanged] {
            host?.enqueue(handler, payload: [.number(Double(fallback))])
        }
        pendingTabFallback = nil
    }

    var selectedTab: AppKitElement? {
        guard !children.isEmpty else { return nil }
        let requested = (view as? AppKitTabbedView)?.selectedIndex ?? whole(.currentPage) ?? 0
        return children[min(max(requested, 0), children.count - 1)]
    }

    var sidebarIsVisible: Bool {
        if let split = view as? AppKitSplitView {
            return split.isEffectivelyPresented
        }
        return value(.isSidebarVisible)?.bool == true
    }

    var nativeMenuItem: NSMenuItem? {
        if type == .menuSeparator {
            if let platformMenuItem { return platformMenuItem }
            let item = NSMenuItem.separator()
            platformMenuItem = item
            return item
        }

        guard type == .menu || type == .menuItem else { return nil }

        let item = platformMenuItem ?? NSMenuItem()
        platformMenuItem = item
        item.title = string(.text) ?? ""
        item.isEnabled = value(.isEnabled)?.bool ?? true
        item.setAccessibilityIdentifier(string(.accessibilityIdentifier))
        item.image = string(.icon).flatMap { image(named: $0) }

        if value(.isDestructive)?.bool == true {
            item.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [.foregroundColor: NSColor.systemRed])
        } else {
            item.attributedTitle = NSAttributedString(string: item.title)
        }

        if type == .menuItem {
            item.target = self
            item.action = #selector(clicked(_:))
            item.submenu = nil
        } else {
            item.target = nil
            item.action = nil
            let menu = item.submenu ?? NSMenu(title: item.title)
            menu.title = item.title
            menu.autoenablesItems = false
            menu.removeAllItems()
            for child in children {
                if let child = child.nativeMenuItem { menu.addItem(child) }
            }
            item.submenu = menu
        }

        return item
    }

    /// Attaches the view's menu slot directly to AppKit. The slot remains a
    /// StateUI child for identity and sparse updates, but never becomes a
    /// visual child in the native layout.
    func configureContextMenu() {
        guard let view else { return }
        guard let slot = slot(.contextMenu) else {
            view.menu = nil
            return
        }

        let items = slot.children.compactMap(\.nativeMenuItem)
        guard !items.isEmpty else {
            view.menu = nil
            return
        }

        let menu = view.menu ?? NSMenu()
        menu.autoenablesItems = false
        menu.removeAllItems()
        for item in items { menu.addItem(item) }
        view.menu = menu
    }

    func popNavigation() {
        guard type == .navigationStack, children.count > 1,
              let handler = events[.popped]
        else { return }

        host?.dispatch(handler, payload: [.number(Double(children.count - 2))])
    }

    func selectTab(from previous: Int, to selected: Int) {
        guard type == .tabbedView, children.indices.contains(selected) else { return }

        if pagePresented {
            if children.indices.contains(previous) {
                children[previous].setPagePresented(false, reason: .appearance)
            }
            children[selected].setPagePresented(true, reason: .appearance)
        }

        host?.commit(events[.currentPageChanged], payload: [.number(Double(selected))])

        // The window's chrome follows what the user sees now - its title,
        // its actions, its row of tabs - whether or not the application binds
        // the selection and renders again.
        host?.refreshWindowChrome()
    }

    func changeSidebarVisibility(to presented: Bool) {
        guard type == .splitView else { return }

        if pagePresented {
            children.first?.setPagePresented(presented, reason: .appearance)
        }

        host?.commit(events[.isSidebarVisibleChanged], payload: [.bool(presented)])
    }

    static let pageTypes: Set<NodeType> = [
        .page, .navigationStack, .tabbedView, .splitView,
    ]
}
#endif
