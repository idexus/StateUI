// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Pages and their arrangements on the Web: a stack's pages in their cell, a split view's panes, and the user's
/// choices handed to the host layer, which tells the pages and the states.
/// Design: docs/design/platforms/web/pages.md
extension WebElement {
    /// Whether a split view's sidebar shows on screen.
    var showsSidebar: Bool? {
        (view as? WebSplitView)?.isPresented
    }

    /// The tab the user chose on a tabbed view, which the tree may not say yet.
    var chosenTab: Int? {
        (view as? WebTabView)?.choice.chosen
    }

    /// Stands an arrangement's pages where they go: a stack's one over another, a split view's in its panes.
    func arrangePages() -> Bool {
        let arranged = element.arrangedChildren.compactMap(\.web.placedElement).map { item in
            (view: item.view!, values: { [weak item] in item?.element.layoutValues ?? LayoutValues() })
        }
        switch view {
        case let stack as WebNavigationView:
            stack.show(arranged.map(\.0))
        case let split as WebSplitView:
            split.sidebar.setItems(Array(arranged.prefix(1)))
            split.detail.setItems(Array(arranged.dropFirst().prefix(1)))
        case let tabs as WebTabView:
            tabs.setTabs(arranged.map(\.0))
        default:
            return false
        }
        return true
    }

    /// Paints a tabbed view's strip in the colors of the bar on its path, as they stand now.
    /// Design: docs/design/host/pages.md#the-bar-a-path-declares
    func showBarColors() {
        (view as? WebTabView)?.showColors(background: element.barColors.background, foreground: element.barColors.foreground)
    }

    /// Keeps a tabbed view and a split view with the tree: the tabs named and the one the tree asks for shown, the
    /// sidebar as the tree says - at once the first time - and what the user chooses heard.
    func followPages(changed: Set<Prop>, wasDescribed: Bool) {
        if let tabs = view as? WebTabView {
            tabs.show(element.children.map { $0.value(.title)?.string ?? "" },
                      icons: element.children.map { HostPicture($0.value(.icon)) },
                      requested: element.value(.selectedTab)?.number.map { Int($0) })
            tabs.onSelection = { [weak self] previous, selected in self?.tabChosen(from: previous, to: selected) }
        }
        guard let split = view as? WebSplitView else { return }
        split.onPresentationChanged = { [weak self] presented in self?.sidebarChanged(to: presented) }
        if changed.contains(.showsSidebar) {
            split.present(element.value(.showsSidebar)?.bool == true, moves: wasDescribed)
        }
        if !changed.isDisjoint(with: MountedElement.sidebarMaterials) {
            split.ground(beside: element.sidebarMaterial(over: false), over: element.sidebarMaterial(over: true))
            host?.refreshChrome()
        }
    }

    /// The user chose another tab: the host layer tells the pages and the state, and shows the chrome again.
    private func tabChosen(from previous: Int, to selected: Int) {
        host?.runtime.tabChosen(element, from: previous, to: selected)
    }

    /// The sidebar showed or hid: the host layer tells its page and the state, and the chrome follows.
    private func sidebarChanged(to presented: Bool) {
        host?.runtime.sidebarShown(element, presented)
        host?.refreshChrome()
    }
}
