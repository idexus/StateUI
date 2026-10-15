// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore

extension NSView {
    /// What of the view AppKit is to draw: the whole of it where it or an ancestor stands under a transform, which
    /// AppKit leaves out of what it takes for `visible`; `visible` otherwise.
    /// Design: docs/design/platforms/appkit/views.md#a-view-under-a-transform
    func drawnRect(visible: NSRect) -> NSRect {
        var view: NSView? = self
        while let each = view {
            if let layer = each.layer, !CATransform3DIsIdentity(layer.transform) { return bounds }
            view = each.superview
        }
        return visible
    }
}
#endif
