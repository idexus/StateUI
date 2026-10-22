// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page, or a container like it: its one child in its room.
@MainActor
class AndroidSingleChildView: AndroidLayoutView {
    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.first, width: width)
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first, item.isShown else { return }

        // A page it holds stands in the whole room, under what stands over it by the page's own rule; anything else
        // stands clear of that.
        if let page = item.view as? AndroidPageView {
            page.roomInsets = roomInsets
            return page.layout(SingleChildArithmetic.place(of: item, in: bounds, direction: direction))
        }
        let room = Rect(
            x: bounds.x + roomInsets.left, y: bounds.y + roomInsets.top,
            width: max(0, bounds.width - roomInsets.left - roomInsets.right),
            height: max(0, bounds.height - roomInsets.top - roomInsets.bottom))
        item.view.layout(SingleChildArithmetic.place(of: item, in: room, direction: direction))
    }
}
