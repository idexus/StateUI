// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One child as its GTK layout places it: its view, and what the layout reads of it.
@MainActor
struct GTKLayoutItem: LayoutChild {
    /// The child's view.
    let view: GTKView

    /// What the layout reads of the child.
    var values = LayoutValues()

    /// Whether the child is shown; a hidden child takes no room.
    var isShown = true

    /// The mounted element the view presents, whose place its layout animates; 0 for none.
    var mount: UInt64 = 0

    /// Fades the view in as it joins a standing layout; nil for a view that simply appears.
    var fadeIn: ((Motion) -> Void)?

    /// The view's size for the width offered to it, its margin already taken out by the layout, its stated sizes
    /// and bounds applied. A stated width is the width it is measured at, so words wrap to it; a most width bounds
    /// the offer.
    func size(offered width: Double?) -> LayoutSize {
        let offer: Double? = if let stated = values.width {
            values.boundedWidth(stated)
        } else {
            [width, values.maximumWidth].compactMap(\.self).min()
        }
        let measured = view.measure(width: offer, height: nil)

        return LayoutSize(
            width: values.boundedWidth(values.width ?? measured.width),
            height: values.boundedHeight(values.height ?? measured.height))
    }

    /// Whether a parent would place this item as it places `other`.
    func arranges(like other: GTKLayoutItem) -> Bool {
        view === other.view && values == other.values && isShown == other.isShown
    }
}
