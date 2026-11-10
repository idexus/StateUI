// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Where the element stands, said to the tree that reads it by the host layer's rule.
/// Design: docs/design/platforms/winui/layout.md#where-a-view-stands
extension WinUIElement: FrameReporter {
    /// Whether the tree reads where this element stands, and it has a view to stand.
    var readsFrame: Bool {
        view != nil && element.readsOwnFrame
    }

    /// Says where the element stands, where that changed (`MountedElement.reportFrame`) - once a layout placed it;
    /// a split view, where its sidebar stands too.
    func reportFrame() {
        guard let host, let view, view.isLaidOut else { return }
        let report = view.frameReport(corner: windowCorner ?? view.origin, safeArea: host.safeAreaOrigin(of: element))
        element.reportFrame(report, in: host.runtime)
        if let split = view as? WinUISplitView { element.reportSidebarOverlays(split.overlays, in: host.runtime) }
    }
}

extension WinUIElement {
    /// Where the top left corner of the view's laid-out rectangle stands in its window, no transform in it.
    /// Design: docs/design/host/runtime.md#a-corner-in-the-window
    var windowCorner: Point? {
        element.cornerInWindow(
            toolkit: { ($0.native as? WinUIElement)?.view?.origin },
            place: { ($0.native as? WinUIElement)?.view.map { Point(x: $0.placedFrame.x, y: $0.placedFrame.y) } },
            scrolled: { (($0.native as? WinUIElement)?.view as? WinUIScrollView)?.offset ?? .zero })
    }
}

extension WinUIScrollView: FramedScroller {}
