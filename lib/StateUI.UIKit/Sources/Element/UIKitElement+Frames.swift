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

    /// Where the view stands now: in its parent, in its window, and from the safe area the window's pages stand in;
    /// nil for a view in no window.
    func frameNumbers() -> [Double]? {
        guard let view, let window = view.window else { return nil }
        let corner = view.convert(view.bounds, to: window).origin
        return MountedElement.frameNumbers(
            place: placedFrame, corner: Point(x: corner.x, y: corner.y),
            content: Point(x: window.safeAreaInsets.left, y: window.safeAreaInsets.top))
    }
}
#endif
