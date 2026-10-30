// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One child as a layout's arithmetic takes it: its view, what the tree says of its place, and whether it shows.
@MainActor
struct UIKitLayoutItem: LayoutChild {
    let view: UIView

    var values = LayoutValues()

    var isShown = true

    /// The mounted element the view is, which a traveling place follows.
    var mount: UInt64 = 0

    /// The element that stands the view where it is placed; nil where the layout sets its frame itself.
    weak var placed: (any PlacedView)?

    /// How the view is drawn over its place, which a placing layout adds its own drawing to.
    weak var drawing: UIKitViewDrawing?

    var fadeIn: ((Motion) -> Void)?

    init(view: UIView, values: LayoutValues = LayoutValues(), isShown: Bool = true) {
        self.view = view
        self.values = values
        self.isShown = isShown
    }

    /// The view's size offered `width`, as the tree's values bound it: a layout's by its arithmetic, a control's
    /// as UIKit fits it.
    func size(offered width: Double?) -> LayoutSize {
        // A view holding new words back is measured at their size.
        if let held = placed?.heldWords { return held }
        let offer = values.offer(width)
        if let layout = view as? UIKitLayoutView { return values.sized(layout.measuredSize(width: offer)) }
        let fitted = view.sizeThatFits(CGSize(width: offer ?? .greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
        return values.sized(LayoutSize(width: fitted.width, height: fitted.height))
    }

    func firstBaseline(offered width: Double?) -> Double? {
        if let layout = view as? UIKitLayoutView { return layout.firstBaseline(width: values.offer(width)) }
        return (view as? UIKitTextView)?.firstBaseline
    }

    func arranges(like other: UIKitLayoutItem) -> Bool {
        view === other.view && values == other.values && isShown == other.isShown
    }
}
#endif
