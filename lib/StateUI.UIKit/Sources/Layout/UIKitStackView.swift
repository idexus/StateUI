// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A VStack or an HStack: its children one after another along its axis (`StackArithmetic`).
@MainActor
final class UIKitStackView: UIKitLayoutView {
    let axis: StackArithmetic.Axis

    var spacing = 0.0 {
        didSet { if spacing != oldValue { invalidate() } }
    }

    var padding = Insets(0) {
        didSet { if padding != oldValue { invalidate() } }
    }

    init(axis: StackArithmetic.Axis) {
        self.axis = axis
        super.init()
    }

    private func invalidate() {
        forgetMeasurements()
        setNeedsLayout()
    }

    override func contentSize(width: Double?) -> LayoutSize {
        StackArithmetic.size(of: items, axis: axis, spacing: spacing, padding: padding, width: width)
    }

    override func arrange(in bounds: Rect) {
        let places = StackArithmetic.places(
            of: items, axis: axis, spacing: spacing, padding: padding, in: bounds, direction: direction)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: place) }
        }
    }
}
#endif
