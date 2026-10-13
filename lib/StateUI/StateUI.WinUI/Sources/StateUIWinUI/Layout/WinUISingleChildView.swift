// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page, or a container like it: its one child in its room - under its title where the window heads the page.
@MainActor
class WinUISingleChildView: WinUILayoutView {
    /// The page's title heading its content; nil for none.
    private(set) var heading: WinUIPageHeading?

    /// Heads the page with `title`; nil takes the heading away.
    /// Design: docs/design/platforms/winui/pages.md#a-pages-heading
    func setHeading(_ title: String?) {
        guard title != heading?.view.text else { return }
        if let title, let heading {
            heading.view.setText(title)
        } else {
            heading = title.map(WinUIPageHeading.init)
            holdChildren()
        }
        invalidateMeasurements()
    }

    override func heldViews() -> [WinUIView] {
        (heading.map { [$0.view] } ?? []) + super.heldViews()
    }

    override func contentSize(width: Double?) -> LayoutSize {
        let child = SingleChildArithmetic.size(of: items.first, width: width)
        guard let heading else { return child }
        return RowEdge.size(page: child, row: heading.height(width: width))
    }

    override func arrange(in bounds: Rect) {
        let room = heading?.place(in: bounds) ?? bounds
        guard let item = items.first, item.isShown else { return }

        item.view.layout(SingleChildArithmetic.place(of: item, in: room, direction: direction))
    }
}
