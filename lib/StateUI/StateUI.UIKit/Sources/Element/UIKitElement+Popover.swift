// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A popover element: UIKit's popover by its anchor's view while it asks to show (`MountedElement.asksToShow`).
/// Design: docs/design/host/pages.md#a-popover
extension UIKitElement {
    func configurePopover() {
        guard element.type == .popover, let content = view else { return }
        guard element.asksToShow else { return shownPopover?.close() ?? () }
        guard let anchor = element.presenter?.uiKit.view else { return }
        guard anchor.window != nil, let root = host?.root(asked: element.enclosing(type: .window)) else {
            return element.waitForItsWindow()
        }
        let popover = shownPopover ?? UIKitPopover(content: content) { [weak self] in self?.popoverClosed() }
        shownPopover = popover
        popover.show(by: anchor, size: content.sizeThatFits(UIView.layoutFittingExpandedSize), in: root)
    }

    /// The user took the popover away (`reportDismissed`).
    private func popoverClosed() {
        guard let host else { return }
        element.reportDismissed(in: host.runtime)
    }
}
#endif
