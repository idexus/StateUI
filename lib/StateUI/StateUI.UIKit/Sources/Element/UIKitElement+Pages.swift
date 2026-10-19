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
        case .tabView: UIKitTabBarController()
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

    /// What a page's bar shows: its title or title view, the line under it and the colours its path declares, its
    /// actions as the host layer orders them, and whether the bar shows and offers the way back. A tabbed view's: its chosen tab's page's, titled as the host
    /// layer names it (`titledPage`) - tabs on a stack by their own title, else by the page beneath.
    /// Design: docs/design/platforms/uikit/pages.md#the-bar
    var chrome: UIKitPageChrome {
        if type == .tabView {
            var chrome = element.selectedTab?.visiblePage?.uiKit.chrome ?? UIKitPageChrome()
            chrome.title = element.titledPage?.value(.title)?.string ?? ""
            chrome.showsTitle = element.titledPage?.value(.showsTitle)?.bool != false
            return chrome
        }

        var chrome = UIKitPageChrome()
        chrome.title = element.barTitle(applicationName: host?.runtime.core.applicationName ?? "")
        chrome.showsTitle = value(.showsTitle)?.bool != false
        chrome.subtitle = element.titleArea?.subtitle
        chrome.titleView = element.chromeTitleView?.uiKit.view
        chrome.showsBar = value(.showsNavigationBar)?.bool != false
        chrome.offersBack = value(.showsBackButton)?.bool != false
        chrome.backButtonTitle = value(.backButtonTitle)?.string
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
            title: item.value(.text)?.string ?? "", icon: HostPicture(item.value(.icon)),
            isEnabled: item.isEffectivelyEnabled, isDestructive: item.value(.isDestructive)?.bool == true,
            identifier: item.value(.accessibilityIdentifier)?.string,
            perform: { [weak item] in item?.uiKit.choose() }, element: item.uiKit)
    }

    /// Writes the bar of every page in this arrangement and every one it holds.
    func composeChrome() {
        switch type {
        case .page:
            if let controller { chrome.show(on: controller.navigationItem, buttons: &barButtonsSaid) }
        case .tabView:
            if let controller { chrome.show(on: controller.navigationItem, buttons: &barButtonsSaid) }
            let tabs = controller as? UIKitTabBarController
            tabs?.showsTheStacksBar = element.showsTheStacksBar
            // A tab bar wears the colours of the bar on its path, which a theme or a state moves on an element above.
            // Design: docs/design/host/pages.md#the-bar-a-path-declares
            tabs?.showColors(background: element.barColors.background, foreground: element.barColors.foreground)
            children.forEach { $0.composeChrome() }
        case .navigationStack:
            (controller as? UIKitNavigationController)?.showTopsBar()
            children.forEach { $0.composeChrome() }
        case .splitView:
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
            // A page comes in wearing its own bar: UIKit takes the bar's look as the move starts, which a layout in
            // the same turn - a sidebar going - can start before the window's chrome is composed.
            children.forEach { $0.composeChrome() }
            navigation.setPages(children.compactMap(\.controller), reducingMotion: host?.reducesMotion() ?? true)
        case .tabView:
            guard let tabs = controller as? UIKitTabBarController else { return }
            tabs.show(
                children.compactMap { tab in
                    tab.controller.map { ($0, tab.value(.title)?.string ?? "", HostPicture(tab.value(.icon))) }
                },
                requested: value(.selectedTab)?.number.map { Int($0) })
            tabs.onSelection = { [weak self] previous, selected in self?.tabChosen(from: previous, to: selected) }
        case .splitView:
            guard let split = controller as? UIKitSplitViewController else { return }
            split.show(sidebar: children.first?.controller, detail: children.dropFirst().first?.controller)
            split.onPresentationChanged = { [weak self] presented in self?.sidebarChanged(to: presented) }
            if let host { split.slide(on: host.runtime.sidebarSlide, mount: element.mount) }
            if changed.contains(.showsSidebar) { split.present(value(.showsSidebar)?.bool == true) }
            if !changed.isDisjoint(with: MountedElement.sidebarMaterials) {
                split.paintsSidebar = element.paintsSidebar
                split.showPageBackgrounds()
            }
        default:
            break
        }
    }

    /// Lets the arrangement's controller say nothing more, as the element leaves the tree.
    func releasePages() {
        (controller as? UIKitNavigationController)?.onPopped = nil
        (controller as? UIKitTabBarController)?.onSelection = nil
        (controller as? UIKitSplitViewController)?.onPresentationChanged = nil
        (controller as? UIKitSplitViewController)?.stopSliding()
    }

    /// The user took the stack's top pages away: the host layer tells the path how long it is now.
    private func userPopped(staying: Int) {
        host?.runtime.stackPopped(element, staying: staying)
    }

    /// The user chose another tab: the host layer tells the pages and the state, and shows the chrome again.
    private func tabChosen(from previous: Int, to selected: Int) {
        host?.runtime.tabChosen(element, from: previous, to: selected)
    }

    /// The sidebar showed or hid: the host layer tells its page and the state.
    private func sidebarChanged(to presented: Bool) {
        host?.runtime.sidebarShown(element, presented)
    }
}
#endif
