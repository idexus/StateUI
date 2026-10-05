// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// The browser's window: the page's whole room, showing one page or an arrangement of pages.
/// Design: docs/design/platforms/web/runtime.md#the-window
@MainActor
final class WebWindow {
    /// The room the window shows its content in, the first of the body's elements.
    let room = WebLayoutView(arrangement: .single)

    init() {
        room.attribute("class", "stateui-window")
        WebRelay.insert(room.node, into: WebRelay.body, at: 0)
    }

    /// Shows `view` in the whole room; nil for nothing.
    func show(_ view: WebDOMView?) {
        room.setItems(view.map { [($0, LayoutValues())] } ?? [])
    }

    func close() {
        room.detach()
    }
}
