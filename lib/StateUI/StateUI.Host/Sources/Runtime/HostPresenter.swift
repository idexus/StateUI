// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a runtime shows and performs through, the toolkit's own: its windows around the mounted tree, and the acts
/// the application calls. The rest of a turn and a frame is the runtime's.
/// Design: docs/design/host/runtime.md#the-runtimes-parts
@_spi(Host) @MainActor public protocol HostPresenter: AnyObject {
    /// Shows what a render changed around the mounted tree: the windows, their pages and their chrome.
    func presentRendered()

    /// Follows a frame's walk outside the tree: the windows' chrome again where `movedChrome` says it moved - a
    /// bar's colour, a window's frame.
    func presentFrame(movedChrome: Bool)

    /// Performs an act the application called, on the interface its handler changed.
    func perform(_ call: HostActCall)
}
