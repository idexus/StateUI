// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One child as its Android layout places it: its view, and what the layout reads of it.
@MainActor
struct AndroidLayoutItem: LayoutChild {
    /// The child's view.
    let view: AndroidView

    /// What the layout reads of the child.
    var values = LayoutValues()

    /// Whether the child is shown; a hidden child takes no room.
    var isShown = true

    /// The mounted element the view presents, whose place its layout animates; 0 for none.
    var mount: UInt64 = 0

    /// Fades the view in as it joins a standing layout; nil for a view that simply appears.
    var fadeIn: ((Motion) -> Void)?

    /// The view's size for the width offered it, as the host layer measures a child (`LayoutValues.offer`,
    /// `sized`): a stated width, within its room, is the width it is measured at, so words wrap to it.
    func size(offered width: Double?) -> LayoutSize {
        let widthSpec = values.offer(width).map {
            ViewConstants.spec(values.width == nil ? ViewConstants.atMost : ViewConstants.exactly, view.pixels($0))
        } ?? ViewConstants.unspecified
        let measured = view.measure(width: widthSpec, height: ViewConstants.unspecified)
        return values.sized(
            LayoutSize(width: Double(measured.width) / view.density, height: Double(measured.height) / view.density))
    }

    /// Whether a parent would place this item as it places `other`.
    func arranges(like other: AndroidLayoutItem) -> Bool {
        view === other.view && values == other.values && isShown == other.isShown
    }
}
