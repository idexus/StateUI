// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A SplitView: UIKit's own split view controller, its sidebar the first column and its detail the second - a page
/// standing alone in a column gets the column's own bar. The sidebar showing or hiding on screen is told, whoever
/// moved it.
/// Design: docs/design/platforms/uikit/pages.md#a-split-view
@MainActor
final class UIKitSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    /// What the controller does when its sidebar showed or hid.
    var onPresentationChanged: ((Bool) -> Void)?

    /// Whether the sidebar shows on screen; nil until UIKit has said.
    private(set) var isPresented: Bool?

    private var shown: (sidebar: UIViewController?, detail: UIViewController?)

    init() {
        super.init(style: .doubleColumn)
        delegate = self
        preferredDisplayMode = .oneBesideSecondary
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitSplitViewController is made in code")
    }

    /// The sidebar's controller and the detail's.
    func show(sidebar: UIViewController?, detail: UIViewController?) {
        if sidebar !== shown.sidebar { setViewController(sidebar, for: .primary) }
        if detail !== shown.detail { setViewController(detail, for: .secondary) }
        shown = (sidebar, detail)
    }

    /// Shows the sidebar, or hides it, as the tree says - the program's move, which UIKit's telling of it does not
    /// report back. Collapsed into one column, as on a phone, the sidebar shows by being the column shown.
    func present(_ presented: Bool) {
        guard presented != isPresented else { return }
        isPresented = presented
        if isCollapsed {
            show(presented ? .primary : .secondary)
        } else if presented {
            show(.primary)
        } else {
            hide(.primary)
        }
    }

    func splitViewController(_ split: UISplitViewController, willShow column: UISplitViewController.Column) {
        guard column == .primary, isPresented != true else { return }
        isPresented = true
        onPresentationChanged?(true)
    }

    func splitViewController(_ split: UISplitViewController, willHide column: UISplitViewController.Column) {
        guard column == .primary, isPresented != false else { return }
        isPresented = false
        onPresentationChanged?(false)
    }

    func splitViewController(
        _ split: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposed: UISplitViewController.Column
    ) -> UISplitViewController.Column {
        .secondary
    }
}
#endif
