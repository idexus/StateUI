// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a runtime shows and performs through, the toolkit's own: its windows around the mounted tree, and the acts
/// the application calls. The rest of a turn and a frame is the runtime's.
/// Design: docs/design/host/runtime.md#the-runtimes-parts
@_spi(Host) @MainActor public protocol HostPresenter: AnyObject {
    /// Shows what a render changed around the mounted tree: the windows, their pages and their chrome, where
    /// `touchedChrome` says it changed what they are made of; a render that did not leaves them as they stand.
    /// Design: docs/design/host/pages.md#a-render-that-touches-the-chrome
    func presentRendered(touchedChrome: Bool)

    /// Follows a frame's walk outside the tree: the windows' chrome again where `movedChrome` says it moved - a
    /// bar's color, a window's frame.
    func presentFrame(movedChrome: Bool)

    /// Performs an act the application called, on the interface its handler changed.
    func perform(_ call: HostActCall)

    /// Opens the address of a link the user chose, as a launched one opens (`HostActPerformer.open(link:)`).
    func open(link address: String)

    /// Puts the keyboard on `element` as the focus act does (`ActToolkit.focus`): a field the keyboard is handed on
    /// to (`NextField`).
    func focus(_ element: MountedElement)
}
