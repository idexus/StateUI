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

    /// Says where the element stands, where that changed (`MountedElement.reportFrame`).
    func reportFrame() {
        guard let host, let view else { return }
        element.reportFrame(view.frameReport(safeArea: host.safeAreaOrigin(of: element)), in: host.runtime)
    }
}

extension WinUIScrollView: FramedScroller {}
