// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

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

    init(content: UIView, of element: MountedElement, onClosed: @escaping () -> Void) {
        self.onClosed = onClosed
        super.init()
        controller.view = UIKitPopoverRoom(content: content, of: element)
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

/// A popover's own view: what it holds laid in the room its safe area gives - clear of the arrow UIKit lays it under
/// on iOS 26, or under it where its content says so - by the rule every room keeps.
/// Design: docs/design/host/layout.md#the-safe-area
@MainActor
private final class UIKitPopoverRoom: UIView {
    private let content: UIView
    private weak var element: MountedElement?

    init(content: UIView, of element: MountedElement) {
        self.content = content
        self.element = element
        super.init(frame: .zero)
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inside = bounds.inset(by: safeAreaInsets)
        let safe = Rect(x: inside.minX, y: inside.minY, width: inside.width, height: inside.height)
        let room = SafeAreaArithmetic.room(
            safe: safe, whole: Rect(x: 0, y: 0, width: bounds.width, height: bounds.height),
            edges: element?.contentSafeArea, direction: element?.layoutDirection ?? .leftToRight)
        content.frame = CGRect(x: room.x, y: room.y, width: room.width, height: room.height)
        (element?.pageScroller?.uiKit.view as? UIKitScrollView)?.keepClear(
            SafeAreaArithmetic.clearance(room: room, safe: safe))
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }
}
#endif
