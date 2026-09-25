// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A VStack or an HStack: the core's stack arithmetic over a panel.
@MainActor
final class GTKStackView: GTKTravellingLayout {
    /// The axis the stack runs along.
    let axis: StackArithmetic.Axis

    /// The room between two children.
    var spacing = 0.0 {
        didSet { if spacing != oldValue { invalidateMeasurements() } }
    }

    /// The room inside the stack's own edge.
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
        beginArrangement(width: bounds.width)
        let places = StackArithmetic.places(
            of: items, axis: axis, spacing: spacing, padding: padding, in: bounds, direction: direction)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: place) }
        }
    }
}
