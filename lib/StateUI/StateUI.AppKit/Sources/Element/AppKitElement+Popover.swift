// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A popover element: AppKit's popover by its anchor's view while it asks to show (`MountedElement.asksToShow`).
/// Design: docs/design/host/pages.md#a-popover
extension AppKitElement {
    func configurePopover() {
        guard element.type == .popover, let content = view as? AppKitSingleChildView else { return }
        guard element.asksToShow else { return shownPopover?.close() ?? () }
        guard let anchor = element.presenter?.appKit.view else { return }
        guard anchor.window != nil else { return element.waitForItsWindow() }
        let popover = shownPopover ?? AppKitPopover(content: content) { [weak self] in self?.popoverClosed() }
        shownPopover = popover
        popover.show(
            by: anchor, size: content.fittingContentSize(width: nil), presenting: host?.presentsWindows ?? true)
    }

    /// AppKit took the popover away: the user's dismissal, or the tree's own coming back (`reportDismissed`).
    private func popoverClosed() {
        guard let host else { return }
        element.reportDismissed(in: host.runtime)
    }
}
#endif
