// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where a bar's button stands on a capsule a host draws behind its bar's groups: on none, the whole of one, or its
/// group's - at the start, in the middle, or at the end.
/// Design: docs/design/host/pages.md#a-bars-capsules
@_spi(Host) public enum BarCapsule: Int32, Sendable, Equatable {
    /// On none: it stands bare.
    case none = 0
    /// On the whole of one: the one button of its group.
    case whole
    /// At its start: its group's first.
    case start
    /// In its middle: between its group's first and last.
    case middle
    /// At its end: its group's last.
    case end

    /// Each button's place of a group of `count` on the bar: every button of a group its author declared stands on
    /// one capsule - one alone on the whole of it - and a lone item's own group, `standsAlone`, stands bare.
    public static func places(count: Int, standsAlone: Bool) -> [BarCapsule] {
        guard !standsAlone, count > 1 else { return Array(repeating: standsAlone ? .none : .whole, count: count) }
        return (0..<count).map { $0 == 0 ? .start : $0 == count - 1 ? .end : .middle }
    }

    /// Each button's place of `group`, the bar's actions as they stand in one of its groups.
    @MainActor
    public static func places(of group: [MountedElement]) -> [BarCapsule] {
        places(count: group.count, standsAlone: group.first?.parent?.value(.standsAlone)?.bool == true)
    }
}
