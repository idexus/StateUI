// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TabView: UIKit's own tab bar controller over its tabs, each named by its page's title and picture. Which tab
/// shows is the host layer's rule (`TabChoice`); the user's choice is told as the tab before and the tab now.
/// Design: docs/design/platforms/uikit/pages.md#tabs
@MainActor
final class UIKitTabBarController: UITabBarController, UITabBarControllerDelegate {
    /// How tall a tab's picture stands - UIKit's icon size for a tab - and on a tab bar made low by a phone on its
    /// side.
    static let glyphHeight = 25.0
    static let lowGlyphHeight = 18.0

    /// Which tab the controller shows.
    private(set) var choice = TabChoice()

    /// What the controller does when the user chooses a tab, handed the one it showed and the one it shows.
    var onSelection: ((_ previous: Int, _ selected: Int) -> Void)?

    /// Whether the stack the tabs stand on shows its bar over them, as the host layer says (`showsTheStacksBar`) -
    /// laid here on a stack of UIKit's own, a collapsed split view's, where no StateUI stack lays it.
    /// Design: docs/design/platforms/uikit/pages.md#a-split-view
    var showsTheStacksBar = true {
        didSet { if showsTheStacksBar != oldValue { layTheStacksBar(animated: false) } }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitTabBarController is made in code")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        layTheStacksBar(animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let stack = uiKitsOwnStack, stack.topViewController !== self else { return }
        stack.setNavigationBarHidden(false, animated: animated)
    }

    /// The stack the tabs stand on where it is UIKit's own.
    private var uiKitsOwnStack: UINavigationController? {
        navigationController.flatMap { $0 is UIKitNavigationController ? nil : $0 }
    }

    private func layTheStacksBar(animated: Bool) {
        guard let stack = uiKitsOwnStack, stack.topViewController === self,
              stack.isNavigationBarHidden == showsTheStacksBar
        else { return }
        stack.setNavigationBarHidden(!showsTheStacksBar, animated: animated)
    }

    /// The tabs, each its controller, its title and its picture, and the tab the tree asks for, where the user has
    /// not chosen another since.
    func show(_ tabs: [(controller: UIViewController, title: String, icon: String?)], requested: Int?) {
        let controllers = tabs.map(\.controller)
        if !(viewControllers ?? []).elementsEqual(controllers, by: ===) {
            setViewControllers(controllers, animated: false)
        }
        for tab in tabs {
            let item = tab.controller.tabBarItem!
            if item.title != tab.title { item.title = tab.title }
            let icon = tab.icon.flatMap { $0.isEmpty ? nil : $0 }
            if item.image?.accessibilityIdentifier != icon {
                item.image = icon.flatMap { UIKitRenderer.glyph(named: $0, height: Self.glyphHeight) }
                item.landscapeImagePhone = icon.flatMap { UIKitRenderer.glyph(named: $0, height: Self.lowGlyphHeight) }
            }
        }
        _ = choice.request(requested)
        if let shown = choice.shown(among: controllers.count), selectedIndex != shown { selectedIndex = shown }
    }

    /// The tab bar's colours: its own where the tree says none.
    func showColors(background: HostValue?, foreground: HostValue?) {
        guard background != nil || foreground != nil else {
            (tabBar.standardAppearance, tabBar.scrollEdgeAppearance) = (UITabBarAppearance(), nil)
            return
        }
        let appearance = UITabBarAppearance()
        if let color = background.flatMap(UIColor.init(stateUI:)) {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = color
        }
        // Words on a painted bar: the colour written, else light on a dark bar and dark on a light one.
        if let color = BandWords.color(on: background, written: foreground).flatMap(UIColor.init(stateUI:)) {
            appearance.stackedLayoutAppearance.selected.iconColor = color
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: color]
        }
        (tabBar.standardAppearance, tabBar.scrollEdgeAppearance) = (appearance, appearance)
    }

    func tabBarController(_ controller: UITabBarController, didSelect selected: UIViewController) {
        guard let tabs = viewControllers, let index = tabs.firstIndex(where: { $0 === selected }),
              let previous = choice.choose(index, of: tabs.count)
        else { return }
        onSelection?(previous, index)
    }
}
#endif
