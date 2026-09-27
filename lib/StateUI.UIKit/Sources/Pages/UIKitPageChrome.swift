// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a page's bar shows: its title or the view standing in for it, its actions - those on the bar and those in
/// its overflow menu - whether it shows and offers the way back, and its colours.
/// Design: docs/design/platforms/uikit/pages.md#the-bar
@MainActor
struct UIKitPageChrome {
    var title = ""
    var titleView: UIView?
    var showsBar = true
    var offersBack = true
    var barBackground: HostValue?
    var barForeground: HostValue?
    var actions: [UIKitBarAction] = []
    var overflow: [UIKitBarAction] = []

    /// Puts it on `item`, the bar a navigation controller shows for the page.
    func show(on item: UINavigationItem) {
        item.title = title
        if item.titleView !== titleView { item.titleView = titleView }
        if let titleView {
            let size = titleView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44))
            titleView.bounds.size = size
        }
        item.hidesBackButton = !offersBack
        item.rightBarButtonItems = actions.reversed().map(\.barItem)
            + (overflow.isEmpty ? [] : [UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: overflow.map(\.menuAction)))])

        guard barBackground != nil || barForeground != nil else {
            (item.standardAppearance, item.scrollEdgeAppearance) = (nil, nil)
            return
        }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        if let background = barBackground.flatMap(UIColor.init(stateUI:)) {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = background
        }
        if let foreground = barForeground.flatMap(UIColor.init(stateUI:)) {
            appearance.titleTextAttributes = [.foregroundColor: foreground]
            appearance.largeTitleTextAttributes = [.foregroundColor: foreground]
            appearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: foreground]
        }
        (item.standardAppearance, item.scrollEdgeAppearance) = (appearance, appearance)
    }
}
#endif
