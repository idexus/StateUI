// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page or an overlay: its one child in its room (`SingleChildArithmetic`).
@MainActor
final class UIKitSingleChildView: UIKitLayoutView {
    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.first, width: width)
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first else { return }
        place(item, at: SingleChildArithmetic.place(of: item, in: bounds, direction: direction))
    }
}
#endif
