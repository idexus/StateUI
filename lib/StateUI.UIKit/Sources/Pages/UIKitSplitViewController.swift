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

    /// Whether the host is moving the columns itself, which UIKit's telling of it does not report back.
    private var replacingDetail = false

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
        if detail !== shown.detail { replace(detail: detail) }
        shown = (sidebar, detail)
    }

    /// Collapsed into one column, UIKit keeps the detail it collapsed on the sidebar's stack whatever the detail
    /// becomes: the host takes it off first, and shows the new one where the detail showed.
    /// Design: docs/design/platforms/uikit/pages.md#a-split-view
    private func replace(detail: UIViewController?) {
        guard isCollapsed else { return setViewController(detail, for: .secondary) }
        replacingDetail = true
        defer { replacingDetail = false }
        viewController(for: .primary)?.navigationController?.popToRootViewController(animated: false)
        setViewController(detail, for: .secondary)
        if isPresented != true { UIView.performWithoutAnimation { show(.secondary) } }
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
        guard column == .primary, isPresented != true, !replacingDetail else { return }
        isPresented = true
        onPresentationChanged?(true)
    }

    func splitViewController(_ split: UISplitViewController, willHide column: UISplitViewController.Column) {
        guard column == .primary, isPresented != false, !replacingDetail else { return }
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
