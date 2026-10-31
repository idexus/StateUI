// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A popover element: Android's popup window by its anchor's view while it asks to show
/// (`MountedElement.asksToShow`).
/// Design: docs/design/host/pages.md#a-popover
extension AndroidElement {
    func configurePopover() {
        guard type == .popover, let popover = view as? AndroidPopoverView else { return }
        guard element.asksToShow else { return popover.close() }
        guard let anchor = element.presenter?.android.view else { return }
        popover.onClosed = { [weak self] in self?.popoverClosed() }
        popover.show(by: anchor)
    }

    /// The user took the popover away (`reportDismissed`).
    private func popoverClosed() {
        guard let host else { return }
        element.reportDismissed(in: host.runtime)
    }
}
