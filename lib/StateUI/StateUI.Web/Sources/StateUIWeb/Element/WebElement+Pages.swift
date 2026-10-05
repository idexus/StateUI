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

    /// Stands an arrangement's pages where they go: a stack's one over another, a split view's in its panes.
    func arrangePages() -> Bool {
        let arranged = element.arrangedChildren.compactMap(\.web.placedElement).map { ($0.view!, $0.element.layoutValues) }
        switch view {
        case let stack as WebNavigationView:
            stack.show(arranged.map(\.0))
        case let split as WebSplitView:
            split.sidebar.setItems(Array(arranged.prefix(1)))
            split.detail.setItems(Array(arranged.dropFirst().prefix(1)))
        default:
            return false
        }
        return true
    }

    /// Keeps a split view with the tree: it shows its sidebar as the tree says - at once the first time - and hears
    /// the user show or hide it.
    func followPages(changed: Set<Prop>, wasDescribed: Bool) {
        guard let split = view as? WebSplitView else { return }
        split.onPresentationChanged = { [weak self] presented in self?.sidebarChanged(to: presented) }
        if changed.contains(.showsSidebar) {
            split.present(element.value(.showsSidebar)?.bool == true, moves: wasDescribed)
        }
    }

    /// The sidebar showed or hid: the host layer tells its page and the state, and the chrome follows.
    private func sidebarChanged(to presented: Bool) {
        host?.runtime.sidebarShown(element, presented)
        host?.refreshChrome()
    }
}
