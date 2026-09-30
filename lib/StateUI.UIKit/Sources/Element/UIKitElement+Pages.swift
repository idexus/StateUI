// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Pages and their arrangements on UIKit: each held by a controller of UIKit's own, the bar a page shows, and the
/// user's choices handed to the host layer, which tells the pages and the states.
/// Design: docs/design/platforms/uikit/pages.md
extension UIKitElement {
    /// The controller an arrangement of pages is: a stack's, a tabbed view's, a split view's.
    func makeController() -> UIViewController? {
        switch type {
        case .navigationStack: UIKitNavigationController()
        case .tabbedView: UIKitTabBarController()
        case .splitView: UIKitSplitViewController()
        default: nil
        }
    }

    /// The tab the user chose on a tabbed view, which the host layer shows.
    var chosenTab: Int? {
        (controller as? UIKitTabBarController)?.choice.chosen
    }

    /// Whether a split view's sidebar shows on screen.
    var showsSidebar: Bool? {
        (controller as? UIKitSplitViewController)?.isPresented
    }

    // MARK: - The bar

    /// What a page's bar shows: its title or title view, its actions as the host layer orders them, whether the bar
    /// shows and offers the way back, and its colours. A tabbed view's: its chosen tab's page's, titled as the host
    /// layer names it (`titledPage`) - tabs on a stack by their own title, else by the page beneath.
    /// Design: docs/design/platforms/uikit/pages.md#the-bar
    var chrome: UIKitPageChrome {
        if type == .tabbedView {
            var chrome = element.selectedTab?.visiblePage?.uiKit.chrome ?? UIKitPageChrome()
            chrome.title = element.titledPage?.value(.title)?.string ?? ""
            return chrome
        }

        var chrome = UIKitPageChrome()
        chrome.title = value(.title)?.string ?? ""
        chrome.titleView = element.chromeTitleView?.uiKit.view
        chrome.showsBar = value(.hasNavigationBar)?.bool != false
        chrome.offersBack = value(.hasBackButton)?.bool != false
        (chrome.barBackground, chrome.barForeground) = element.barColors
        let actions = element.chromeActions
        chrome.leadingActions = actions.leading.map { $0.map(Self.action) }
        chrome.actions = actions.trailing.map { $0.map(Self.action) }
        chrome.overflow = actions.overflow.map(Self.action)
        return chrome
    }

    /// A page's action as the bar takes it.
    private static func action(_ item: MountedElement) -> UIKitBarAction {
        UIKitBarAction(
            title: item.value(.text)?.string ?? "", icon: item.value(.icon)?.string,
            isEnabled: item.value(.isEnabled)?.bool ?? true, isDestructive: item.value(.isDestructive)?.bool == true,
            identifier: item.value(.accessibilityIdentifier)?.string,
            perform: { [weak item] in item?.uiKit.send(.clicked, []) }, element: item.uiKit)
    }

    /// Writes the bar of every page in this arrangement and every one it holds.
    func composeChrome() {
        switch type {
        case .page:
            if let controller { chrome.show(on: controller.navigationItem) }
        case .tabbedView:
            if let controller { chrome.show(on: controller.navigationItem) }
            (controller as? UIKitTabBarController)?.showsTheStacksBar = element.showsTheStacksBar
            children.forEach { $0.composeChrome() }
        case .navigationStack, .splitView:
            children.forEach { $0.composeChrome() }
        default:
            break
        }
    }

    // MARK: - The arrangement

    /// Keeps an arrangement's controller with the tree: a stack's pages, a tabbed view's tabs, a split view's two
    /// columns and its sidebar as the tree says.
    func arrangePages(changed: Set<Prop>) {
        switch type {
        case .navigationStack:
            guard let navigation = controller as? UIKitNavigationController else { return }
            navigation.onPopped = { [weak self] staying in self?.userPopped(staying: staying) }
            navigation.showsBar = { [weak self] shown in
                self?.children.first { $0.controller === shown }?.element.showsTheStacksBar ?? true
            }
            navigation.setPages(children.compactMap(\.controller), animated: !(host?.reducesMotion() ?? true))
        case .tabbedView:
            guard let tabs = controller as? UIKitTabBarController else { return }
            tabs.show(
                children.compactMap { tab in
                    tab.controller.map { ($0, tab.value(.title)?.string ?? "", tab.value(.icon)?.string) }
                },
                requested: value(.currentPage)?.number.map { Int($0) })
            tabs.onSelection = { [weak self] previous, selected in self?.tabChosen(from: previous, to: selected) }
            tabs.showColors(background: element.barColors.background, foreground: element.barColors.foreground)
        case .splitView:
            guard let split = controller as? UIKitSplitViewController else { return }
            split.show(sidebar: children.first?.controller, detail: children.dropFirst().first?.controller)
            split.onPresentationChanged = { [weak self] presented in self?.sidebarChanged(to: presented) }
            if changed.contains(.isSidebarVisible) { split.present(value(.isSidebarVisible)?.bool == true) }
        default:
            break
        }
    }

    /// Lets the arrangement's controller say nothing more, as the element leaves the tree.
    func releasePages() {
        (controller as? UIKitNavigationController)?.onPopped = nil
        (controller as? UIKitTabBarController)?.onSelection = nil
        (controller as? UIKitSplitViewController)?.onPresentationChanged = nil
    }

    /// The user took the stack's top pages away: the stack is told how many stay, as the index of its top.
    private func userPopped(staying: Int) {
        guard let handler = element.handler(.popped) else { return }
        host?.runtime.dispatch(handler, payload: [.number(Double(staying - 1))])
    }

    /// The user chose another tab: the host layer tells the pages and the state; the bars follow what the user sees.
    private func tabChosen(from previous: Int, to selected: Int) {
        host?.runtime.tabChosen(element, from: previous, to: selected)
        composeChrome()
    }

    /// The sidebar showed or hid: the host layer tells its page and the state.
    private func sidebarChanged(to presented: Bool) {
        host?.runtime.sidebarShown(element, presented)
    }
}
#endif
