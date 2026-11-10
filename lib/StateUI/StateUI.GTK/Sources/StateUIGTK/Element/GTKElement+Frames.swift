// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Where the element stands, said to the tree that reads it by the host layer's rule.
/// Design: docs/design/platforms/gtk/layout.md#where-a-view-stands
extension GTKElement: FrameReporter {
    /// Whether the tree reads where this element stands, and it has a view to stand.
    var readsFrame: Bool {
        view != nil && element.readsOwnFrame
    }

    /// Says where the element stands, where that changed (`MountedElement.reportFrame`); nothing while it stands
    /// nowhere yet - a split view, where its sidebar stands too.
    func reportFrame() {
        guard let host, let numbers = view?.frameReport(corner: windowCorner) else { return }
        element.reportFrame(numbers, in: host.runtime)
        if let split = view as? GTKSplitView { element.reportSidebarOverlays(split.isCollapsed, in: host.runtime) }
    }
}

extension GTKElement {
    /// Where the top left corner of the view's laid-out rectangle stands in its window, no transform in it.
    /// Design: docs/design/host/runtime.md#a-corner-in-the-window
    var windowCorner: Point? {
        element.cornerInWindow(
            toolkit: { ($0.native as? GTKElement)?.view?.cornerAsDrawn },
            place: { ($0.native as? GTKElement)?.view.map { Point(x: $0.placedFrame.x, y: $0.placedFrame.y) } },
            scrolled: { (($0.native as? GTKElement)?.view as? GTKScrollView)?.offset ?? .zero })
    }
}

extension GTKScrollView: FramedScroller {}
