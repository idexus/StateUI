// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A split view's one adaptation, the same on every host: first given room at least as wide as the platform's own
/// breakpoint, it shows its sidebar, said as the user's; after that the user and the application decide. A host
/// whose toolkit places no sidebar by width of itself places it by `place`.
/// Design: docs/design/host/pages.md#a-sidebar-on-the-first-room
@_spi(Host) public struct SidebarAdaptation: Sendable {
    private var adapted = false

    /// Whether the sidebar last stood beside the detail; nil before it stood anywhere.
    private var placedBeside: Bool?

    /// No room given yet.
    public init() {}

    /// The split view is given `width`, its sidebar `shown` or not: whether it shows the sidebar now. Only the first
    /// room wider than nothing decides.
    public mutating func room(_ width: Double, breakpoint: Double, shown: Bool) -> Bool {
        guard !adapted, width > 0 else { return false }

        adapted = true
        return !shown && width >= breakpoint
    }

    /// Where the sidebar stands in `width` - beside the detail from `breakpoint`, over it below - and whether, `shown`,
    /// it closes now: one beside the detail closes as the window narrows it over, as the platform's own panes do.
    public mutating func place(_ width: Double, breakpoint: Double, shown: Bool) -> (beside: Bool, closes: Bool) {
        let beside = width >= breakpoint
        defer { placedBeside = beside }
        return (beside, shown && placedBeside == true && !beside)
    }
}
