// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Where the element stands, said to the tree that reads it by the host layer's rule: after anything was laid out,
/// on the display's next frame.
/// Design: docs/design/host/runtime.md#where-a-view-stands
extension UIKitElement: FrameReporter {
    /// Whether the tree reads where this element stands, and it has a view to stand.
    var readsFrame: Bool {
        view != nil && element.readsOwnFrame
    }

    /// Says where the element stands, where that changed (`MountedElement.reportFrame`).
    func reportFrame() {
        guard let host, let numbers = frameNumbers() else { return }
        element.reportFrame(numbers, in: host.runtime)
    }

    /// Where the view stands now: in its parent, in its window, and from the safe area of the page it stands on -
    /// under the page's bars as well as the screen's; nil for a view in no window, or one no layout placed yet -
    /// StateUI's, or UIKit's giving it a size.
    func frameNumbers() -> [Double]? {
        guard let view, let window = view.window, isPlaced || view.bounds.size != .zero else { return nil }
        let corner = view.convert(view.bounds, to: window).origin
        let safe = Self.safeCorner(of: view, in: window)
        return MountedElement.frameNumbers(
            place: placedFrame, corner: Point(x: corner.x, y: corner.y), content: Point(x: safe.x, y: safe.y))
    }

    /// The corner of the safe area `view`'s page stands in, in `window`; the window's own where no page holds it.
    private static func safeCorner(of view: UIView, in window: UIWindow) -> CGPoint {
        var responder: UIResponder? = view
        while let each = responder, !(each is UIKitPageController) { responder = each.next }
        guard let page = responder as? UIKitPageController, let view = page.view else {
            return CGPoint(x: window.safeAreaInsets.left, y: window.safeAreaInsets.top)
        }
        return view.convert(view.bounds.inset(by: page.safeInsets).origin, to: window)
    }
}

extension UIKitScrollView: FramedScroller {}
#endif
