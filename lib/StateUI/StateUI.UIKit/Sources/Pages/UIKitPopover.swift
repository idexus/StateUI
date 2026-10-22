// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// A view's popover: UIKit's popover presentation of the popover element's view by its anchor - a popover on a phone
/// too - passed over what the window presents (`UIKitRootViewController.pass`); `onClosed` hears the user take it
/// away.
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
        controller.view = UIKitPopoverRoom(content: content)
        controller.modalPresentationStyle = .popover
    }

    /// Shows the popover by `anchor` at `size`, over what `root`'s window presents.
    func show(by anchor: UIView, size: CGSize, in root: UIKitRootViewController) {
        controller.preferredContentSize = size
        let popover = controller.popoverPresentationController
        // Shown by a view made anew - its branch flipped: it stands by the new one.
        if popover?.sourceView !== anchor {
            popover?.sourceView = anchor
            popover?.sourceRect = anchor.bounds
        }
        guard !isShown else { return }
        isShown = true
        self.root = root
        popover?.delegate = self
        root.pass(controller)
    }

    /// A popover on a phone too, by its view: UIKit would make it a sheet where the room is compact.
    func adaptivePresentationStyle(
        for controller: UIPresentationController, traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        .none
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

/// A popover's own view: what it holds laid within its safe area, clear of the arrow UIKit lays it under on iOS 26.
/// Design: docs/design/platforms/uikit/pages.md#a-popover
@MainActor
private final class UIKitPopoverRoom: UIView {
    private let content: UIView

    init(content: UIView) {
        self.content = content
        super.init(frame: .zero)
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds.inset(by: safeAreaInsets)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }
}
#endif
