// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Pages and their arrangements on AppKit: a tabbed view's tabs and a split view's sidebar kept with the tree, the
/// user's choices on them handed to the host layer, which tells the pages and the states, and menus built from the
/// host layer's walk.
/// Design: docs/design/host/pages.md
extension AppKitElement {
    /// The tab the user chose on a tabbed view, which the host layer shows.
    var chosenTab: Int? {
        (view as? AppKitTabbedView)?.choice.chosen
    }

    /// Whether a split view's sidebar shows on screen.
    var showsSidebar: Bool? {
        (view as? AppKitSplitView)?.isEffectivelyPresented
    }

    /// The window's arrangement of pages among its children.
    var pageNode: AppKitElement? {
        children.first { NodeType.pageTypes.contains($0.type) }
    }

    var pageView: NSView? {
        pageNode?.presentableViews.first
    }

    var presentablePageView: NSView? { presentableViews.first }

    var modalStackNode: AppKitElement? {
        children.first { $0.type == .modalStack }
    }

    var overlayItem: AppKitLayoutItem? {
        slot(.overlay)?.children.first?.layoutItem
    }

    /// The tabs of a tabbed view: its pages, each under its title and its picture, the tab the tree asks for, and
    /// whether they stand in the window's row.
    func arrangeTabs(_ tabs: AppKitTabbedView) {
        tabs.tabsShownByWindow = element.tabsStandInWindow
        tabs.onSelection = { [weak self] previous, selected in self?.tabChosen(from: previous, to: selected) }
        tabs.setItems(
            children.compactMap { child in
                child.layoutItem.map {
                    AppKitTabItem(layout: $0, title: child.string(.title), image: child.image(.icon))
                }
            },
            requestedIndex: whole(.currentPage))
    }

    /// The user chose another tab: the host layer tells the pages and the state, and the window's chrome follows what
    /// the user sees whether or not the application renders again.
    private func tabChosen(from previous: Int, to selected: Int) {
        host?.runtime.tabChosen(element, from: previous, to: selected)
        host?.refreshWindowChrome()
    }

    /// The sidebar showed or hid on screen: the host layer tells its page and the state.
    func sidebarShown(_ presented: Bool) {
        host?.runtime.sidebarShown(element, presented)
    }

    /// Attaches the view's context menu slot to AppKit. The slot stays a child for identity and sparse updates, but
    /// never becomes a visual child in the native layout.
    func configureContextMenu() {
        guard let view else { return }
        let items = slot(.contextMenu).map { AppKitMenus.items(MenuEntry.entries(of: $0.element)) } ?? []
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
}

/// AppKit's menus, built from the host layer's walk: a native item for each entry, kept on its element so the same
/// item stands across walks, each item telling its element when chosen.
@MainActor
enum AppKitMenus {
    /// The native items for `entries`, in order.
    static func items(_ entries: [MenuEntry]) -> [NSMenuItem] {
        entries.map(item)
    }

    private static func item(_ entry: MenuEntry) -> NSMenuItem {
        guard let element = entry.element?.appKit else { return .separator() }

        let item = element.platformMenuItem ?? NSMenuItem()
        element.platformMenuItem = item
        item.title = entry.title
        item.isEnabled = entry.isEnabled
        item.setAccessibilityIdentifier(entry.identifier)
        item.image = entry.icon.flatMap { element.image(named: $0) }
        item.attributedTitle = NSAttributedString(
            string: entry.title, attributes: entry.isDestructive ? [.foregroundColor: NSColor.systemRed] : [:])

        if entry.kind == .item {
            item.target = element
            item.action = #selector(AppKitElement.clicked(_:))
            item.submenu = nil
        } else {
            item.target = nil
            item.action = nil
            let menu = item.submenu ?? NSMenu(title: entry.title)
            menu.title = entry.title
            menu.autoenablesItems = false
            menu.removeAllItems()
            for child in items(entry.entries) { menu.addItem(child) }
            item.submenu = menu
        }
        return item
    }
}
#endif
