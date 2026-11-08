// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A container of one child in its room: an overlay, a list's row, a popover - and a page, which adds its title and
/// its bars (`WinUIPageView`).
@MainActor
class WinUISingleChildView: WinUILayoutView {
    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.first, width: width)
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first, item.isShown else { return }

        item.view.layout(SingleChildArithmetic.place(of: item, in: bounds, direction: direction))
    }
}
