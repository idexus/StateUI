// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's title heading its content in the platform's title style, as Windows' own applications head a page
/// while their title bar names the application: a row across the top of the page's room, the content under it.
/// Design: docs/design/platforms/winui/pages.md#a-pages-heading
@MainActor
final class WinUIPageHeading {
    /// The title's words.
    let view = WinUITextView()

    /// How far the title stands from the room's top and sides, in DIPs.
    static let inset = 24.0

    /// A heading saying `title`.
    init(_ title: String) {
        var look = TextLook()
        look.style = .title
        view.setTextFont(look)
        view.setText(title)
    }

    /// The heading's row height for a room `width` DIPs wide.
    func height(width: Double?) -> Double {
        let words = view.measure(width: width.map { max(0, $0 - 2 * Self.inset) }, height: nil)
        return Self.inset + words.height
    }

    /// Stands the title at the top of `bounds`; the room left under it.
    func place(in bounds: Rect) -> Rect {
        let (row, room) = RowEdge.top.split(bounds, row: height(width: bounds.width))
        view.layout(Rect(
            x: row.x + Self.inset, y: row.y + Self.inset, width: max(0, row.width - 2 * Self.inset),
            height: max(0, row.height - Self.inset)))
        return room
    }
}
