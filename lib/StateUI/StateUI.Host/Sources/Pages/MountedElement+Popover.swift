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

    /// The element whose view this popover stands by: the one it is declared on, or what the anchor it is declared
    /// on shows.
    public var presenter: MountedElement? {
        parent?.presentingElement
    }

    /// Whether this popover asks to show.
    public var asksToShow: Bool {
        value(.isPresented)?.bool == true
    }

    /// What this anchor shows is to be made anew - its view's branch flips: the popover it holds, shown, is on its way
    /// to the new view until its host takes it again after the render, and a closing meanwhile - its old view
    /// leaving - is nobody's.
    func willShowAnew() {
        guard type == .anchor, let popover, popover.asksToShow else { return }
        popover.isMoving = true
    }

    /// What this anchor shows was made: the popover it holds, asking to show, is tried again after the render, as
    /// one waiting for its window is - by the view the anchor shows now (`presenter`), which stood nowhere while
    /// the anchor's children were being made.
    func showsAnew() {
        guard type == .anchor, let popover, popover.asksToShow else { return }
        tree?.wait(popover)
    }

    /// Its host cannot show this popover yet - the window it stands in is not made: it is tried again once the
    /// render stands (`MountedTree.takeWaitingPopovers`).
    public func waitForItsWindow() {
        tree?.wait(self)
    }

    /// The platform took this popover away. While the tree asks for it, that is the user's dismissal - false onto
    /// the state, then the event; while it does not, the application's own, heard by nobody.
    public func reportDismissed(in runtime: HostRuntime) {
        guard asksToShow, !isMoving else { return }
        reportUserChange(.isPresented, .isPresentedChanged, .bool(false), in: runtime)
    }
}
