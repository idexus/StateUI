// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Pages and their arrangements on WinUI: a tabbed view's row and a split view's pane kept with the tree, and the
/// user's choices on them handed to the host layer, which tells the pages and the states.
/// Design: docs/design/platforms/winui/pages.md
extension WinUIElement {
    /// The tab the user chose on a tabbed view, which the host layer shows.
    var chosenTab: Int? {
        (view as? WinUITabbedView)?.choice.chosen
    }

    /// Whether a split view's sidebar shows on screen.
    var showsSidebar: Bool? {
        (view as? WinUISplitView)?.isPresented
    }

    /// Keeps an arrangement's own parts with the tree: a tabbed view's row, a split view's sidebar.
    func arrangePages(changed: Set<Prop>) {
        switch type {
        case .tabbedView:
            guard let tabs = view as? WinUITabbedView else { return }
            tabs.tabsShownByWindow = element.tabsStandInWindow
            tabs.show(children.map { $0.value(.title)?.string ?? "" }, requested: value(.currentPage)?.number.map { Int($0) })
            tabs.onSelection = { [weak self] previous, selected in self?.tabChosen(from: previous, to: selected) }
        case .splitView:
            guard let split = view as? WinUISplitView else { return }
            // The split's first room is decided inside a layout pass, and said once the pass is over.
            split.onPresentationChanged = { [weak self] presented in
                WinUIDoorbell.afterPass { [weak self] in self?.sidebarShown(presented) }
            }
            if changed.contains(.isSidebarVisible) { split.present(value(.isSidebarVisible)?.bool == true) }
        default:
            break
        }
    }

    /// The user chose another tab: the host layer tells the pages and the state, and the window's chrome follows what
    /// the user sees whether or not the application renders again.
    private func tabChosen(from previous: Int, to selected: Int) {
        host?.runtime.tabChosen(element, from: previous, to: selected)
        host?.refreshWindowChrome()
    }

    /// The user showed or hid a split view's sidebar through the window's chrome.
    func changeSidebarVisibility(to presented: Bool) {
        guard type == .splitView, let split = view as? WinUISplitView, split.isPresented != presented else { return }

        split.present(presented)
        sidebarShown(presented)
    }

    /// The sidebar showed or hid: the host layer tells its page and the state, and the chrome follows.
    private func sidebarShown(_ presented: Bool) {
        host?.runtime.sidebarShown(element, presented)
        host?.refreshWindowChrome()
    }
}
