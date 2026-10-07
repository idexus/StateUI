// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a window's element says of the window it is, the same on every host: whether the user may maximize and
/// minimize it - nil where it says nothing, which leaves the toolkit's own - the backdrop the desktop shows through,
/// what it shows behind its pages, and whether it floats over the application's other windows now.
/// Design: docs/design/host/tree.md#a-windows-traits
@_spi(Host) public struct WindowTraits: Equatable, Sendable {
    /// Whether the user may maximize the window, where said.
    public var isMaximizable: Bool?

    /// Whether the user may minimize the window, where said.
    public var isMinimizable: Bool?

    /// The glass or material the desktop shows through the window in, where said; nil for an opaque window.
    public var backdrop: HostBackdrop?

    /// What the window shows behind its pages, where said.
    public var background: HostValue?

    /// Whether the window floats over the application's other windows: it says so, and the application is in front.
    public var floatsOnTop: Bool

    /// What `window` says now, standing in `lifecycle`; a trait it leaves unsaid is false, but for the two the
    /// toolkit keeps.
    @MainActor public init(of window: MountedElement, in lifecycle: ApplicationLifecycle) {
        isMaximizable = window.value(.isMaximizable)?.bool
        isMinimizable = window.value(.isMinimizable)?.bool
        backdrop = HostBackdrop(window.value(.backdrop))
        background = window.value(.background)
        floatsOnTop = lifecycle.floats(window)
    }
}
