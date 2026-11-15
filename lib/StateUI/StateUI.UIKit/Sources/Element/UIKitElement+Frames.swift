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

    /// Says where the element stands, where that changed (`MountedElement.reportFrame`) - a split view, where its
    /// sidebar stands too.
    func reportFrame() {
        guard let host, let numbers = frameNumbers() else { return }
        element.reportFrame(numbers, in: host.runtime)
        if let split = controller as? UIKitSplitViewController {
            element.reportSidebarOverlays(split.overlays, in: host.runtime)
        }
    }

    /// Where the view stands now: in its parent, in its window, and from the safe area of the page it stands on -
    /// under the page's bars as well as the screen's; nil for a view in no window, or one no layout placed yet -
    /// StateUI's, or UIKit's giving it a size.
    func frameNumbers() -> [Double]? {
        guard let view, let window = view.window,
              MountedElement.isLaidOut(placed: isPlaced, width: view.bounds.width, height: view.bounds.height)
        else { return nil }
        let safe = Self.safeCorner(of: view, in: window)
        return MountedElement.frameNumbers(
            place: placedFrame, corner: windowCorner ?? .zero, content: Point(x: safe.x, y: safe.y))
    }

    /// Where the top left corner of the view's laid-out rectangle stands in its window, no transform in it.
    /// Design: docs/design/host/runtime.md#a-corner-in-the-window
    var windowCorner: Point? {
        element.cornerInWindow(
            toolkit: { ($0.native as? UIKitElement)?.cornerAsDrawn },
            place: { ($0.native as? UIKitElement).map { Point(x: $0.placedFrame.x, y: $0.placedFrame.y) } },
            scrolled: { ($0.native as? UIKitElement)?.scrolled ?? .zero })
    }

    /// Where the view's top left corner stands in its window as UIKit converts it, the transforms on it and above it
    /// in; nil for a view in no window.
    private var cornerAsDrawn: Point? {
        guard let view, let window = view.window else { return nil }
        let corner = view.convert(view.bounds, to: window).origin
        return Point(x: corner.x, y: corner.y)
    }

    /// How far a scroller's content has moved: its scroller's offset; none for any other view.
    private var scrolled: Point {
        guard let offset = (view as? UIKitScrollView)?.scroller.contentOffset else { return Point(x: 0, y: 0) }
        return Point(x: offset.x, y: offset.y)
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
