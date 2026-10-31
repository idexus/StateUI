// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A popover's view: what it holds, in the document's own popover over everything, under its anchor while it shows;
/// `onClosed` hears the user take it away - a click beside it, Escape.
/// Design: docs/design/platforms/web/pages.md#a-popover
@MainActor
final class WebPopoverView: WebLayoutView {
    var onClosed: (() -> Void)?

    /// Whether the program wants the popover shown: a closing while it does is the user's.
    private var wanted = false

    /// Whether the popover stands in the document, over everything.
    private var standing = false

    init() {
        super.init(tag: "div", arrangement: .single)
        attribute("class", "stateui-popover")
        attribute("popover", "auto")
        hear(.closed) { [weak self] in self?.closedByTheBrowser() }
    }

    /// Shows the popover under `anchor`'s view.
    func show(by anchor: WebDOMView) {
        wanted = true
        if !standing {
            WebRelay.insert(node, into: WebRelay.body, at: 0)
            standing = true
        }
        WebRelay.showPopover(node, under: anchor.node)
    }

    func close() {
        wanted = false
        WebRelay.hidePopover(node)
    }

    private func closedByTheBrowser() {
        guard wanted else { return }
        wanted = false
        onClosed?()
    }

    override func release() {
        close()
        onClosed = nil
        super.release()
    }
}
