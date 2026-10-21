// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A popover a view declares, shown by it as its state says - the same on every host.
/// Design: docs/design/host/pages.md#a-popover
extension MountedElement {
    /// The popover this element declares, where it declares one.
    public var popover: MountedElement? {
        children.first { $0.type == .popover }
    }

    /// Whether this popover asks to show.
    public var asksToShow: Bool {
        value(.isShown)?.bool == true
    }

    /// Its host cannot show this popover yet - the window it stands in is not made: it is tried again once the
    /// render stands (`MountedTree.takeWaitingPopovers`).
    public func waitForItsWindow() {
        tree?.wait(self)
    }

    /// The platform took this popover away. While the tree asks for it, that is the user's dismissal - false onto
    /// the state, then the event; while it does not, the application's own, heard by nobody.
    public func reportDismissed(in runtime: HostRuntime) {
        guard asksToShow else { return }
        reportUserChange(.isShown, .isShownChanged, .bool(false), in: runtime)
    }
}
