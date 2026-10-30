// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

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

    /// The view's size for the width offered it, margin taken out (`LayoutValues.offer`, `sized`).
    func size(offered width: Double?) -> LayoutSize {
        // A view holding new words back is measured at their size.
        if let held = view.heldWords { return held }
        let offer = values.offer(width)
        // A layout of StateUI's is measured at the width it stands at; its size for any width is the arithmetic's.
        // Design: docs/design/platforms/winui/layout.md#measured-every-pass
        let measured: LayoutSize
        if let layout = view as? WinUILayoutView {
            if WinUIView.arranging == 0 { _ = view.measure(width: layout.standsAt ?? offer, height: nil) }
            measured = layout.naturalSize(width: offer)
        } else {
            measured = view.measured(width: offer)
        }

        return values.sized(measured)
    }

    /// Design: docs/design/host/layout.md#a-first-baseline
    func firstBaseline(offered width: Double?) -> Double? {
        if let layout = view as? WinUILayoutView { return layout.firstBaseline(width: values.offer(width)) }
        _ = size(offered: width)
        let baseline = stateui_winui_first_baseline(view.handle)
        return baseline >= 0 ? baseline : nil
    }

    /// Whether a parent would place this item as it places `other`.
    func arranges(like other: WinUILayoutItem) -> Bool {
        view === other.view && values == other.values && isShown == other.isShown
    }
}
