// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a window's element says of the window it is, the same on every host: whether the user may maximize and
/// minimize it - nil where it says nothing, which leaves the toolkit's own - whether the desktop shows through it,
/// whether it floats over the application's other windows, and whether it hides while another application is in use.
/// Design: docs/design/host/tree.md#a-windows-traits
@_spi(Host) public struct WindowTraits: Equatable, Sendable {
    /// Whether the user may maximize the window, where said.
    public var isMaximizable: Bool?

    /// Whether the user may minimize the window, where said.
    public var isMinimizable: Bool?

    /// Whether the desktop shows through the window.
    public var isTranslucent: Bool

    /// Whether the window floats over the application's other windows.
    public var floatsOnTop: Bool

    /// Whether the window hides while another application is in use.
    public var hidesWhenInactive: Bool

    /// What `window` says now; a trait it leaves unsaid is false, but for the two the toolkit keeps.
    @MainActor public init(of window: MountedElement) {
        isMaximizable = window.value(.isMaximizable)?.bool
        isMinimizable = window.value(.isMinimizable)?.bool
        isTranslucent = window.value(.isTranslucent)?.bool == true
        floatsOnTop = window.value(.floatsOnTop)?.bool == true
        hidesWhenInactive = window.value(.hidesWhenInactive)?.bool == true
    }
}
