// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's title heading its content in the platform's title style, the page's line under it, as Windows' own
/// applications head a page while their title bar names the application: a row across the top of the page's room,
/// the content under it.
/// Design: docs/design/platforms/winui/pages.md#a-pages-heading
@MainActor
final class WinUIPageHeading {
    /// The title's words.
    let view = WinUITextView()

    /// The line under the title; empty for none.
    let line = WinUITextView()

    /// How far the title stands from the room's top and sides, in DIPs.
    static let inset = 24.0

    /// A heading saying `title`, and `said` under it.
    init(_ title: String, line said: String?) {
        var look = TextLook()
        look.style = .title
        view.setTextFont(look)
        view.setText(title)
        var under = TextLook()
        under.style = .body
        line.setTextFont(under)
        line.setText(said ?? "")
    }

    /// The views the heading shows: the title, and the line where it says one.
    var views: [WinUIView] { line.text.isEmpty ? [view] : [view, line] }

    /// The heading's row height for a room `width` DIPs wide.
    func height(width: Double?) -> Double {
        let room = width.map { max(0, $0 - 2 * Self.inset) }
        let under = line.text.isEmpty ? 0 : line.measure(width: room, height: nil).height
        return Self.inset + view.measure(width: room, height: nil).height + under
    }

    /// Stands the title at the top of `bounds`, the line under it; the room left under them.
    func place(in bounds: Rect) -> Rect {
        let (row, room) = RowEdge.top.split(bounds, row: height(width: bounds.width))
        let width = max(0, row.width - 2 * Self.inset)
        let words = view.measure(width: width, height: nil).height
        view.layout(Rect(x: row.x + Self.inset, y: row.y + Self.inset, width: width, height: words))
        line.layout(Rect(
            x: row.x + Self.inset, y: row.y + Self.inset + words, width: width,
            height: max(0, row.height - Self.inset - words)))
        return room
    }
}
