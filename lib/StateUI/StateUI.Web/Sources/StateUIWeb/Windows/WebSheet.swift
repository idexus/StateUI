// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page a modal stack presents, on a sheet: the browser's own modal `<dialog>` over the window - a card in the
/// middle, from the bottom where the page is narrow - its bar the page's chrome with a button closing it, the page
/// in the room under it. Escape closes it as that button does: the tree decides.
/// Design: docs/design/platforms/web/pages.md#sheets
@MainActor
final class WebSheet {
    private let dialog = WebDOMView(tag: "dialog")
    let bar = WebWindowBar()
    private let room = WebLayoutView(arrangement: .single)

    /// The view the sheet shows.
    let page: WebDOMView

    /// What the sheet does when the user closes it.
    var onClosedByUser: () -> Void = {}

    init(page: WebDOMView) {
        self.page = page
        dialog.attribute("class", "stateui-sheet")
        room.attribute("class", "stateui-sheet-room")
        WebRelay.insert(bar.node, into: dialog.node, at: 0)
        WebRelay.insert(room.node, into: dialog.node, at: 1)
        room.setItems([(page, LayoutValues())])
        bar.onClose = { [weak self] in self?.onClosedByUser() }
        dialog.listen("dismiss") { [weak self] in self?.onClosedByUser() }
    }

    /// Shows the sheet over the window and the sheets before it.
    func present() {
        WebRelay.insert(dialog.node, into: WebRelay.body, at: 0)
        WebRelay.showModal(dialog.node)
    }

    /// Takes the sheet away; its page stays the tree's.
    func close() {
        WebRelay.closeModal(dialog.node)
        room.setItems([])
        bar.detach()
        room.detach()
        dialog.detach()
    }
}
