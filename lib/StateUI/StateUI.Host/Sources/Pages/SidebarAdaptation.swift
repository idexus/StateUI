// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A split view's one adaptation, the same on every host: first given room at least as wide as the platform's own
/// breakpoint, it shows its sidebar, said as the user's; after that the user and the application decide.
/// Design: docs/design/host/pages.md#a-sidebar-on-the-first-room
@_spi(Host) public struct SidebarAdaptation: Sendable {
    private var adapted = false

    /// No room given yet.
    public init() {}

    /// The split view is given `width`, its sidebar `shown` or not: whether it shows the sidebar now. Only the first
    /// room wider than nothing decides.
    public mutating func room(_ width: Double, breakpoint: Double, shown: Bool) -> Bool {
        guard !adapted, width > 0 else { return false }

        adapted = true
        return !shown && width >= breakpoint
    }
}
