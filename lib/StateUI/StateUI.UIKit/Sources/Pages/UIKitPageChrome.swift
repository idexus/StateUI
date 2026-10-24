// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a page's bar shows: its title or the view standing in for it, the line under the title, its groups of actions
/// at either edge and those in its overflow menu, whether it shows and offers the way back, and its colors.
/// Design: docs/design/platforms/uikit/pages.md#the-bar
@MainActor
struct UIKitPageChrome {
    var title = ""
    /// Whether the bar shows the title; the title names the way back all the same.
    var showsTitle = true
    var subtitle: String?
    var titleView: UIView?
    var showsBar = true
    var offersBack = true
    /// What the way back from the page above this one says; nil for UIKit's own.
    var backButtonTitle: String?
    var barBackground: HostValue?
    var barForeground: HostValue?
    var leadingActions: [[UIKitBarAction]] = []
    var actions: [[UIKitBarAction]] = []
    var overflow: [UIKitBarAction] = []
    /// What the bar's close button does, where the page's stack stands in a sheet and offers one; nil for none.
    var closes: (() -> Void)?

    /// What the bar's buttons say, the leading groups, the trailing, the overflow and the close.
    var buttonsSaid: [[UIKitBarAction.Said]] {
        leadingActions.map { $0.map(\.said) } + [[]] + actions.map { $0.map(\.said) } + [overflow.map(\.said)]
            + [closes == nil ? [] : [Self.closeSaid]]
    }

    /// What the close button says among the bar's buttons, and the identifier of its action.
    private static let closeSaid = UIKitBarAction.Said(
        title: "", icon: nil, isEnabled: true, isDestructive: false, identifier: closeIdentifier.rawValue, mount: nil,
        isOn: nil)
    static let closeIdentifier = UIAction.Identifier("stateui.close")

    /// Puts it on `item`, the bar a navigation controller shows for the page - its buttons made again only where
    /// they say something else than `standing` says, else recolored; `standing` then says what they say.
    func show(on item: UINavigationItem, buttons standing: inout [[UIKitBarAction.Said]]?) {
        item.title = title
        if item.subtitle != subtitle { item.subtitle = subtitle }
        // A layout's size follows what it holds; a control is fitted once and keeps the width the bar gives it:
        // fitted to its words at every render, it would be cut and widened by the bar, letter by letter.
        // Design: docs/design/platforms/uikit/pages.md#the-bar
        if let titleView, item.titleView !== titleView || titleView is UIKitLayoutView || titleView.bounds.isEmpty {
            titleView.bounds.size = titleView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44))
        }
        // A page showing no title stands nothing in its place: the item keeps the title for the way back.
        if titleView == nil, !showsTitle {
            if !(item.titleView is NoTitle) { item.titleView = NoTitle() }
        } else if item.titleView !== titleView {
            item.titleView = titleView
        }
        item.hidesBackButton = !offersBack
        if item.backButtonTitle != backButtonTitle { item.backButtonTitle = backButtonTitle }
        // Each group its own background; the leading ones beside the way back.
        // Design: docs/design/platforms/uikit/pages.md#the-bar
        item.leftItemsSupplementBackButton = true
        // Words on a painted bar: the color written, else light on a dark bar and dark on a light one.
        let painted = barBackground != nil || barForeground != nil
        let words = painted ? BandWords.color(on: barBackground, written: barForeground) : nil
        let foreground = words.flatMap(UIColor.init(stateUI:))
        if buttonsSaid != standing {
            standing = buttonsSaid
            item.leadingItemGroups = leadingActions.map { Self.group($0.map { $0.barItem(tint: foreground) }) }
            let menu = overflow.isEmpty ? [] : [[UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: overflow.map(\.overflowEntry)))]]
            menu.joined().forEach { $0.tintColor = foreground }
            // The sheet's close at the trailing edge, UIKit's own button.
            let close = closes.map { closes in
                [UIBarButtonItem(systemItem: .close, primaryAction: UIAction(identifier: Self.closeIdentifier) { _ in
                    closes()
                })]
            }
            close?.forEach { $0.tintColor = foreground }
            item.trailingItemGroups = actions.map { Self.group($0.map { $0.barItem(tint: foreground) }) }
                + menu.map(Self.group) + (close.map { [Self.group($0)] } ?? [])
        } else {
            for (group, actions) in zip(item.leadingItemGroups + item.trailingItemGroups, leadingActions + actions) {
                for (button, action) in zip(group.barButtonItems, actions) { button.tintColor = action.tint(foreground) }
            }
            item.trailingItemGroups.dropFirst(actions.count).flatMap(\.barButtonItems).forEach {
                $0.tintColor = foreground
            }
        }

        guard painted else {
            (item.standardAppearance, item.scrollEdgeAppearance) = (nil, nil)
            return
        }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        if HostBrush(barBackground).isClear {
            // A clear bar shows what is behind it as it is: no ground, and no line under it.
            appearance.configureWithTransparentBackground()
        } else if let background = barBackground.flatMap(UIColor.init(stateUI:)) {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = background
        }
        if let foreground {
            appearance.titleTextAttributes = [.foregroundColor: foreground]
            appearance.largeTitleTextAttributes = [.foregroundColor: foreground]
            appearance.subtitleTextAttributes = [.foregroundColor: foreground]
            appearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: foreground]
            appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: foreground]
            let back = UIImage(systemName: "chevron.backward")?.withTintColor(foreground, renderingMode: .alwaysOriginal)
            appearance.setBackIndicatorImage(back, transitionMaskImage: back)
        }
        (item.standardAppearance, item.scrollEdgeAppearance) = (appearance, appearance)
    }

    /// One group of the bar's items, drawn on one background.
    private static func group(_ items: [UIBarButtonItem]) -> UIBarButtonItemGroup {
        UIBarButtonItemGroup(barButtonItems: items, representativeItem: nil)
    }
}
/// What a bar shows in place of the title of a page showing none.
private final class NoTitle: UIView {}
#endif
