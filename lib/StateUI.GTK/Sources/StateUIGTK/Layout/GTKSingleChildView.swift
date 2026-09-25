// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A page, or a container like it: its one child within its padding.
@MainActor
class GTKSingleChildView: GTKLayoutView {
    /// The room inside the view's own edge.
    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidateMeasurements() } }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.first, padding: padding, width: width)
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first, item.isShown else { return }

        item.view.layout(SingleChildArithmetic.place(of: item, in: bounds, padding: padding, direction: direction))
    }
}
