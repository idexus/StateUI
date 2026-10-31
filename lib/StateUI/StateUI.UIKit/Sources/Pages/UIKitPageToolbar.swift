// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the bar at a page's foot shows (`.toolbar(.bottom)`): its groups at either edge and those in its overflow
/// menu, on the toolbar of the page's navigation controller, which shows while its top page holds items.
/// Design: docs/design/platforms/uikit/pages.md#the-bar-at-the-foot
@MainActor
struct UIKitPageToolbar {
    var leadingActions: [[UIKitBarAction]] = []
    var actions: [[UIKitBarAction]] = []
    var overflow: [UIKitBarAction] = []

    /// What the space between the bar's edges, and its More button, are identified by.
    static let betweenIdentifier = "stateui.toolbar.between"
    static let moreIdentifier = "stateui.toolbar.more"

    /// What the bar's items say, the leading groups, the trailing and the overflow.
    var itemsSaid: [[UIKitBarAction.Said]] {
        leadingActions.map { $0.map(\.said) } + [[]] + actions.map { $0.map(\.said) } + [overflow.map(\.said)]
    }

    /// Puts it on `controller`'s toolbar items, made again only where they say something else than `standing` says;
    /// `standing` then says what they say.
    func show(on controller: UIViewController, items standing: inout [[UIKitBarAction.Said]]?) {
        guard itemsSaid != standing else { return }
        standing = itemsSaid
        let groups = { (groups: [[UIKitBarAction]]) in groups.map { $0.map { $0.barItem(tint: nil) } } }
        let more = UIBarButtonItem(
            title: CoreLink().chromeWords.more, image: UIImage(systemName: "ellipsis.circle"), primaryAction: nil,
            menu: UIMenu(children: overflow.map(\.overflowEntry)))
        more.identifier = Self.moreIdentifier
        // Each group its own background - apart by a fixed space - the leading ones before the space between the
        // edges, the rest after it; the space and the More button stand as the same items from page to page.
        let separate = { (groups: [[UIBarButtonItem]]) in Array(groups.joined(separator: [UIBarButtonItem.fixedSpace()])) }
        let leading = separate(groups(leadingActions))
        let trailing = separate(groups(actions) + (overflow.isEmpty ? [] : [[more]]))
        let between = UIBarButtonItem.flexibleSpace()
        between.identifier = Self.betweenIdentifier
        let items = leading.isEmpty && trailing.isEmpty ? [] : leading + [between] + trailing
        controller.setToolbarItems(items, animated: false)
        (controller.navigationController as? UIKitNavigationController)?.showTopsBar()
    }
}
#endif
