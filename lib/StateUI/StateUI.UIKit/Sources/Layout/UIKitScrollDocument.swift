// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a ScrollView's scroller moves: its content where the host layer's scroll arithmetic puts it, in a document
/// at least as large as the viewport.
/// Design: docs/design/platforms/uikit/layout.md#scrolling
@MainActor
final class UIKitScrollDocument: UIKitLayoutView {
    /// The room inside the scroller's own edge.
    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidate() } }
    }

    var orientation = ScrollOrientation.vertical {
        didSet { if orientation != oldValue { invalidate() } }
    }

    private func invalidate() {
        forgetMeasurements()
        setNeedsLayout()
    }

    override func contentSize(width: Double?) -> LayoutSize {
        ScrollArithmetic.contentSize(of: items.first, padding: padding, orientation: orientation, width: width)
    }

    /// The document's size in `viewport`.
    func documentSize(in viewport: LayoutSize) -> LayoutSize {
        guard let item = items.first, item.isShown else { return viewport }
        return ScrollArithmetic.arrange(item, padding: padding, orientation: orientation, in: viewport).document
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first, item.isShown else { return }
        let arranged = ScrollArithmetic.arrange(
            item, padding: padding, orientation: orientation, in: LayoutSize(width: bounds.width, height: bounds.height))
        place(item, at: arranged.place)
    }
}
#endif
