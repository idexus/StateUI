// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a window's element says of the window it is, the same on every host: whether the user may maximize and
/// minimize it - nil where it says nothing, which leaves the toolkit's own - what it is made of behind its pages, and
/// whether it floats over the application's other windows now.
/// Design: docs/design/host/tree.md#a-windows-traits
@_spi(Host) public struct WindowTraits: Equatable, Sendable {
    /// Whether the user may maximize the window, where said.
    public var isMaximizable: Bool?

    /// Whether the user may minimize the window, where said.
    public var isMinimizable: Bool?

    /// What the window is made of behind its pages - a colour, or a blur or glass the desktop shows through; empty
    /// for the platform's own window.
    public var background: HostMaterial

    /// Whether the window floats over the application's other windows: it says so, and the application is in front.
    public var floatsOnTop: Bool

    /// What `window` says now, standing in `lifecycle`; a trait it leaves unsaid is false, but for the two the
    /// toolkit keeps.
    @MainActor public init(of window: MountedElement, in lifecycle: ApplicationLifecycle) {
        isMaximizable = window.value(.isMaximizable)?.bool
        isMinimizable = window.value(.isMinimizable)?.bool
        background = HostMaterial(window.value(.background))
        floatsOnTop = lifecycle.floats(window)
    }
}
