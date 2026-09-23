// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a ScrollView's Android scroller moves: its content where the core's scroll arithmetic puts it,
/// in a document the scroller makes at least as large as its viewport.
/// Design: docs/design/platforms/android/layout.md#scrolling
@MainActor
final class AndroidScrollDocument: AndroidLayoutView {
    /// The room inside the scroller's own edge, in points.
    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidateMeasurements() } }
    }

    var orientation = ScrollOrientation.vertical {
        didSet { if orientation != oldValue { invalidateMeasurements() } }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        ScrollArithmetic.contentSize(of: items.first, padding: padding, orientation: orientation, width: width)
    }

    /// Its own size is the document's: never smaller than the viewport, which the scroller saw to.
    override func arrange(in bounds: Rect) {
        guard let item = items.first, item.isShown else { return }

        let arranged = ScrollArithmetic.arrange(
            item, padding: padding, orientation: orientation,
            in: LayoutSize(width: bounds.width, height: bounds.height))
        item.view.layout(arranged.place)
    }
}
