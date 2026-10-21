// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the user does to the element's view, reported to the core.
extension AndroidElement {
    /// An event the view raised, with what it carries, to the handler the tree listens with.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let host else { return }
        element.send(event, values, in: host.runtime)
    }

    /// A menu's entry or a bar's item chosen (`MountedElement.chosen`).
    func choose() {
        guard let host else { return }
        element.chosen(in: host.runtime)
    }

    /// A value the user changed in the view, by the host layer's rule (`reportUserChange`).
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }
        element.reportUserChange(property, event, value, in: host.runtime)
    }

    /// The user pulled the view to refresh it, by the host layer's rule (`reportRefreshRequested`): whether its spinner
    /// stays.
    func pulled() -> Bool {
        guard let host else { return false }
        return element.reportRefreshRequested(in: host.runtime)
    }

    /// The user moved a scroller from `old` to `new`, as the display's frame saw it.
    func scrolled(from old: Point, to new: Point) {
        guard let host else { return }
        element.reportScrolled(from: old, to: new, in: host.runtime)
    }

    /// Whether the tree reads where this element stands (`MountedElement.readsOwnFrame`), where it shows a view.
    var readsFrame: Bool {
        view != nil && element.readsOwnFrame
    }

}

extension AndroidElement: FrameReporter {
    /// Says where the element stands, where that changed (`MountedElement.reportFrame`): its place in its parent as
    /// Android holds it, its corner in the window, and that corner from the page's - under its stack's bar - or the
    /// window's content where no page holds it; nothing before a layout placed it - a split view, where its sidebar
    /// stands too.
    /// Design: docs/design/platforms/android/layout.md#where-a-view-stands
    func reportFrame() {
        guard let host, let view, readsFrame, view.isLaidOut else { return }
        let page = element.enclosing(type: .page)?.android.view
        element.reportFrame(
            MountedElement.frameNumbers(
                place: view.standingFrame, corner: view.cornerInWindow, content: page?.cornerInWindow ?? host.safeAreaOrigin),
            in: host.runtime)
        if let split = view as? AndroidSplitView { element.reportSidebarOverlays(split.overlays, in: host.runtime) }
    }
}
