// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI

/// A scroller's edge under a bar as UIKit draws the edge StateUI asks for: its own automatic one, its hard one, or
/// none.
/// Design: docs/design/host/layout.md#a-bar-at-the-top
extension UIScrollEdgeEffect {
    /// Draws `edge`, writing only what changes.
    func show(_ edge: ScrollEdge) {
        let style: UIScrollEdgeEffect.Style = edge == .hard ? .hard : .automatic
        if self.style != style { self.style = style }
        if isHidden != (edge == .none) { isHidden = edge == .none }
    }

    /// The edge it draws.
    var shown: ScrollEdge {
        isHidden ? ScrollEdge.none : style == .hard ? .hard : .automatic
    }
}
#endif
