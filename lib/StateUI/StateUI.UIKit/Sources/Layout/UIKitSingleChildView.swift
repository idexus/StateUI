// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page or an overlay: its one child within its padding (`SingleChildArithmetic`).
@MainActor
final class UIKitSingleChildView: UIKitLayoutView {
    var padding = Insets(0) {
        didSet {
            guard padding != oldValue else { return }
            forgetMeasurements()
            setNeedsLayout()
        }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.first, padding: padding, width: width)
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first else { return }
        place(item, at: SingleChildArithmetic.place(of: item, in: bounds, padding: padding, direction: direction))
    }
}
#endif
