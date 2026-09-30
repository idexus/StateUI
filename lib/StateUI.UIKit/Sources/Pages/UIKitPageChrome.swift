// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a page's bar shows: its title or the view standing in for it, its groups of actions at either edge and those
/// in its overflow menu, whether it shows and offers the way back, and its colours.
/// Design: docs/design/platforms/uikit/pages.md#the-bar
@MainActor
struct UIKitPageChrome {
    var title = ""
    var titleView: UIView?
    var showsBar = true
    var offersBack = true
    var barBackground: HostValue?
    var barForeground: HostValue?
    var leadingActions: [[UIKitBarAction]] = []
    var actions: [[UIKitBarAction]] = []
    var overflow: [UIKitBarAction] = []

    /// Puts it on `item`, the bar a navigation controller shows for the page.
    func show(on item: UINavigationItem) {
        item.title = title
        // A layout's size follows what it holds; a control keeps the width the bar gave it, which a fit to its
        // words at every render cut and the bar widened again, letter by letter.
        // Design: docs/design/platforms/uikit/pages.md#the-bar
        if let titleView, item.titleView !== titleView || titleView is UIKitLayoutView || titleView.bounds.isEmpty {
            titleView.bounds.size = titleView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44))
        }
        if item.titleView !== titleView { item.titleView = titleView }
        item.hidesBackButton = !offersBack
        // Each group its own background; the leading ones beside the way back.
        // Design: docs/design/platforms/uikit/pages.md#the-bar
        item.leftItemsSupplementBackButton = true
        item.leadingItemGroups = leadingActions.map(Self.group)
        let menu = overflow.isEmpty ? [] : [[UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: overflow.map(\.menuAction)))]]
        item.trailingItemGroups = actions.map { $0.map(\.barItem) }.map(Self.group) + menu.map(Self.group)

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
        // Words on a painted bar: the colour written, else light on a dark bar and dark on a light one.
        let words = BandWords.color(on: barBackground, written: barForeground)
        if let foreground = words.flatMap(UIColor.init(stateUI:)) {
            appearance.titleTextAttributes = [.foregroundColor: foreground]
            appearance.largeTitleTextAttributes = [.foregroundColor: foreground]
            appearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: foreground]
            appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: foreground]
            let back = UIImage(systemName: "chevron.backward")?.withTintColor(foreground, renderingMode: .alwaysOriginal)
            appearance.setBackIndicatorImage(back, transitionMaskImage: back)
            (item.leadingItemGroups + item.trailingItemGroups).flatMap(\.barButtonItems).forEach {
                $0.tintColor = foreground
            }
        }
        (item.standardAppearance, item.scrollEdgeAppearance) = (appearance, appearance)
    }

    /// One group of the bar, drawn on one background.
    private static func group(_ actions: [UIKitBarAction]) -> UIBarButtonItemGroup {
        group(actions.map(\.barItem))
    }

    /// One group of the bar's items, drawn on one background.
    private static func group(_ items: [UIBarButtonItem]) -> UIBarButtonItemGroup {
        UIBarButtonItemGroup(barButtonItems: items, representativeItem: nil)
    }
}
#endif
