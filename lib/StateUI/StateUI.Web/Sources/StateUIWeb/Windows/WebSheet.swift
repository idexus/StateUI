// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page a view presents, on a sheet: the browser's own modal `<dialog>` over the window - a card in the
/// middle, from the bottom where the page is narrow - its bar, where a stack in it brings one, the page's chrome
/// with a button closing it, the page in the room under it. Escape is the user's dismissal: the tree decides.
/// Design: docs/design/platforms/web/pages.md#sheets
@MainActor
final class WebSheet {
    private let dialog = WebDOMView(tag: "dialog")
    let bar = WebWindowBar()
    private let room = WebLayoutView(arrangement: .single)

    /// What the sheet lays over its page, each layer over the dialog whole, the first lowest; a touch beside what
    /// they hold goes on to the page.
    private let overlays = WebLayoutView(arrangement: .layers)

    /// The view the sheet shows.
    let page: WebDOMView

    /// What the sheet does when the user closes it.
    var onClosedByUser: () -> Void = {}

    init(page: WebDOMView) {
        self.page = page
        dialog.attribute("class", "stateui-sheet")
        room.attribute("class", "stateui-sheet-room")
        overlays.attribute("class", "stateui-overlays")
        overlays.style("position", "absolute")
        overlays.style("inset", "0")
        overlays.setLetsInputThrough(true)
        WebRelay.insert(bar.node, into: dialog.node, at: 0)
        WebRelay.insert(room.node, into: dialog.node, at: 1)
        WebRelay.insert(overlays.node, into: dialog.node, at: 2)
        room.setItems([(page, { LayoutValues() })])
        bar.onClose = { [weak self] in self?.onClosedByUser() }
        dialog.hear(.dismiss) { [weak self] in self?.onClosedByUser() }
    }

    /// Shows the sheet over the window and the sheets before it.
    func present() {
        WebRelay.insert(dialog.node, into: WebRelay.body, at: 0)
        WebRelay.showModal(dialog.node)
    }

    /// Lays `layers` over the page, the first lowest.
    /// Design: docs/design/platforms/web/pages.md#overlays
    func showOverlays(_ layers: [WebDOMView]) {
        overlays.setItems(layers.map { ($0, { LayoutValues() }) })
    }

    /// Stands the sheet as large as its page where it `fits`, at the dialog's standard size otherwise (`SheetSize`).
    func fits(_ fits: Bool) {
        dialog.attribute("data-fits", fits ? "" : nil)
    }

    /// Shows the bar's close button where `offers`, which closes the sheet as the user's dismissal.
    func offersClose(_ offers: Bool) {
        bar.onClose = offers ? { [weak self] in self?.onClosedByUser() } : nil
    }

    /// Stands the sheet on `ground` - its window's background - laid over the sheet's own surface; on that surface
    /// alone where it is empty.
    /// Design: docs/design/platforms/web/pages.md#sheets
    func stand(on ground: HostMaterial) {
        let painted = WebCSS.fill(ground.painted)
        let opaque = ground.painted.flatMap { HostBrush($0).firstColor?.color?.alpha } == 255
        dialog.style("background-color", opaque ? painted : nil)
        dialog.style("background-image", opaque ? nil : painted.map { "linear-gradient(\($0), \($0))" })
    }

    /// The dialog's element, which a driver reads the sheet's ground off.
    var dialogNode: Int32 { dialog.node }

    /// Takes the sheet away; its page stays the tree's.
    func close() {
        WebRelay.closeModal(dialog.node)
        room.setItems([])
        overlays.setItems([])
        bar.release()
        room.release()
        overlays.release()
        dialog.release()
    }
}
