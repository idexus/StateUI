// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One child as its WinUI layout places it: its view, and what the layout reads of it.
@MainActor
struct WinUILayoutItem: LayoutChild {
    /// The child's view.
    let view: WinUIView

    /// What the layout reads of the child.
    var values = LayoutValues()

    /// Whether the child is shown; a hidden child takes no room.
    var isShown = true

    /// The mounted element the view presents, whose place its layout animates; 0 for none.
    var mount: UInt64 = 0

    /// Fades the view in as it joins a standing layout; nil for a view that simply appears.
    var fadeIn: ((Motion) -> Void)?

    /// The view's size for the width offered to it, its stated sizes and bounds applied. A stated width is the
    /// width it is measured at, so words wrap to it; a most width bounds the offer.
    func size(offered width: Double?) -> LayoutSize {
        let offer: Double? = if let stated = values.width {
            values.boundedWidth(stated)
        } else {
            [width, values.maximumWidth].compactMap(\.self).min()
        }
        var measured = view.measure(width: offer, height: nil)
        if let layout = view as? WinUILayoutView { measured = layout.naturalSize(width: offer) }

        return LayoutSize(
            width: values.boundedWidth(values.width ?? measured.width),
            height: values.boundedHeight(values.height ?? measured.height))
    }

    /// Whether a parent would place this item as it places `other`.
    func arranges(like other: WinUILayoutItem) -> Bool {
        view === other.view && values == other.values && isShown == other.isShown
    }
}
