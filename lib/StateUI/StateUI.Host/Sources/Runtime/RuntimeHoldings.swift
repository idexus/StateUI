// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a runtime holds for what it shows and moves, a count an owner: what stood before a view came, moved and
/// went stands after, so a walk of many rounds compares two of these and names the owner that kept something.
/// Design: docs/design/host/benchmarks.md#what-a-runtime-holds
@_spi(Host) public struct RuntimeHoldings: Equatable, Sendable, CustomStringConvertible {
    /// The elements mounted and what the tree indexes them by.
    public let tree: Int

    /// The views kept as they leave.
    public let leaving: Int

    /// The animations under way, whoever started them.
    public let animations: Int

    /// The described properties moving, and the views a layout's motion seats.
    public let motions: Int

    /// The state channels and what they keep beside them.
    public let channels: Int

    /// The presentation changes opened or waiting, and the views a shared transition noted.
    public let changes: Int

    /// The numbers a hand holds, the wheels open and the sidebars sliding.
    public let hands: Int

    /// The scrollers and the frame reporters the display's frames serve.
    public let followers: Int

    /// Whether the frame clock is held.
    public let holdsClock: Bool

    /// Every count by its name, on one line.
    public var description: String {
        "tree \(tree), leaving \(leaving), animations \(animations), motions \(motions), channels \(channels), "
            + "changes \(changes), hands \(hands), followers \(followers), clock \(holdsClock ? "held" : "free")"
    }
}

extension HostRuntime {
    /// What the runtime holds now.
    public var holdings: RuntimeHoldings {
        RuntimeHoldings(
            tree: tree.entries, leaving: tree.exits.count, animations: animator.entries,
            motions: describedMotion.entries + layoutMotion.entries, channels: stateChannels.entries,
            changes: tree.changes.entries + tree.shared.entries,
            hands: interactions.entries + handPace.entries + sidebarSlide.entries, followers: frames.entries,
            holdsClock: clock.held)
    }
}
