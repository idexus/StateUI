// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a ScrollView's scroller moves: its content where the core's scroll arithmetic puts it, in a document the
/// viewport makes at least as large as itself.
/// Design: docs/design/platforms/gtk/layout.md#scrolling
@MainActor
final class GTKScrollDocument: GTKLayoutView {
    /// The room inside the scroller's own edge.
    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidateMeasurements() } }
    }

    var orientation = ScrollOrientation.vertical {
        didSet { if orientation != oldValue { invalidateMeasurements() } }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        ScrollArithmetic.contentSize(of: items.first, padding: padding, orientation: orientation, width: width)
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first, item.isShown else { return }

        let arranged = ScrollArithmetic.arrange(
            item, padding: padding, orientation: orientation,
            in: LayoutSize(width: bounds.width, height: bounds.height))
        item.view.layout(arranged.place)
    }
}
