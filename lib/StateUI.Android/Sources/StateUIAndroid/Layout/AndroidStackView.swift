// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A VStack or an HStack: the core's stack arithmetic over a `StateUIViewGroup`.
@MainActor
final class AndroidStackView: AndroidLayoutView {
    /// The axis the stack runs along.
    let axis: StackArithmetic.Axis

    /// The room between two children, in points.
    var spacing = 0.0 {
        didSet { if spacing != oldValue { invalidateMeasurements() } }
    }

    /// The room inside the stack's own edge, in points.
    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidateMeasurements() } }
    }

    init(axis: StackArithmetic.Axis) {
        self.axis = axis
        super.init()
    }

    override func contentSize(width: Double?) -> LayoutSize {
        StackArithmetic.size(of: items, axis: axis, spacing: spacing, padding: padding, width: width)
    }

    override func arrange(in bounds: Rect) {
        let places = StackArithmetic.places(of: items, axis: axis, spacing: spacing, padding: padding, in: bounds)
        for (item, place) in zip(items, places) {
            if let place { item.view.layout(place) }
        }
    }
}
