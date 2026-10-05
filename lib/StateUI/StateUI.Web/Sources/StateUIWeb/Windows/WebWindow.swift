// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// The browser's window: its bar over the room it shows one page or an arrangement of pages in.
/// Design: docs/design/platforms/web/runtime.md#the-window
@MainActor
final class WebWindow {
    /// The window's whole room, the first of the body's elements.
    let frame = WebDOMView(tag: "div")

    let bar = WebWindowBar()

    /// The room under the bar, where the pages stand.
    let room = WebLayoutView(arrangement: .single)

    /// What the window lays over its pages, each layer over the room whole, the first lowest; a touch beside what
    /// they hold goes on to the pages.
    let overlays = WebLayoutView(arrangement: .layers)

    init() {
        frame.attribute("class", "stateui-window")
        room.attribute("class", "stateui-room")
        overlays.attribute("class", "stateui-overlays")
        overlays.setLetsInputThrough(true)
        WebRelay.insert(bar.node, into: frame.node, at: 0)
        WebRelay.insert(room.node, into: frame.node, at: 1)
        WebRelay.insert(overlays.node, into: frame.node, at: 2)
        WebRelay.insert(frame.node, into: WebRelay.body, at: 0)
    }

    /// Shows `view` in the whole room; nil for nothing.
    func show(_ view: WebDOMView?) {
        room.setItems(view.map { [($0, LayoutValues())] } ?? [])
    }

    /// Lays `layers` over the room, the first lowest.
    /// Design: docs/design/platforms/web/pages.md#overlays
    func showOverlays(_ layers: [WebDOMView]) {
        overlays.setItems(layers.map { ($0, LayoutValues()) })
    }

    func close() {
        bar.detach()
        room.detach()
        overlays.detach()
        frame.detach()
    }
}
