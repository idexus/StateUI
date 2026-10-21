// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// A view's popover: UIKit's popover presentation of the popover element's view by its anchor - a sheet on a phone,
/// as UIKit adapts it - passed over what the window presents (`UIKitRootViewController.pass`); `onClosed` hears the
/// user take it away.
/// Design: docs/design/platforms/uikit/pages.md#a-popover
@MainActor
final class UIKitPopover: NSObject, UIPopoverPresentationControllerDelegate {
    let controller = UIViewController()
    private let onClosed: () -> Void
    private weak var root: UIKitRootViewController?

    /// Whether it stands shown, or passes on its way to.
    private(set) var isShown = false

    init(content: UIView, onClosed: @escaping () -> Void) {
        self.onClosed = onClosed
        super.init()
        controller.view = content
        controller.modalPresentationStyle = .popover
    }

    /// Shows the popover by `anchor` at `size`, over what `root`'s window presents.
    func show(by anchor: UIView, size: CGSize, in root: UIKitRootViewController) {
        controller.preferredContentSize = size
        guard !isShown else { return }
        isShown = true
        self.root = root
        let popover = controller.popoverPresentationController
        popover?.sourceView = anchor
        popover?.sourceRect = anchor.bounds
        popover?.delegate = self
        root.pass(controller)
    }

    func close() {
        guard isShown else { return }
        isShown = false
        root?.passed(controller)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        isShown = false
        root?.passed(controller)
        onClosed()
    }
}
#endif
