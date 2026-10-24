// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Which of a bar's groups of actions stand on it, where the host measures its bar itself - the same on every such
/// host: all of them around the title in the bar's middle; else around a title taking the room they leave; else the
/// first in reading order while they fit, the rest behind the bar's More, ahead of what stands there anyway - as the
/// platforms' own bars keep their first items.
/// Design: docs/design/host/pages.md#a-bar-with-no-room
@_spi(Host) public enum BarFit {
    /// How the title stands among the actions.
    public enum Title: Sendable, Equatable {
        /// In the bar's middle, the actions at its edges.
        case centered
        /// In the room the actions leave between them.
        case between
    }

    /// How many of the bar's groups stand on it, the first in reading order, and how its title stands.
    public struct Standing: Sendable, Equatable {
        public var groups: Int
        public var title: Title

        public init(groups: Int, title: Title) {
            self.groups = groups
            self.title = title
        }
    }

    /// The first standing of a bar of `groups` that `fits` - the host trying each on its bar - in the rule's order:
    /// every group around the title centered, then around the title between, one group fewer each time; none of
    /// them where nothing fits.
    public static func standing(groups: Int, fits: (Standing) -> Bool) -> Standing {
        let all = Standing(groups: groups, title: .centered)
        if fits(all) { return all }
        for count in stride(from: groups, to: 0, by: -1) {
            let between = Standing(groups: count, title: .between)
            if fits(between) { return between }
        }
        return Standing(groups: 0, title: .between)
    }

    /// What stands behind the bar's More: the items of each group that left the bar, each group apart, then those
    /// placed behind it anyway.
    @MainActor
    public static func behind(left: [[MountedElement]], placed: [MountedElement]) -> [MenuEntry] {
        var entries: [MenuEntry] = []
        for items in left + [placed] where !items.isEmpty {
            if !entries.isEmpty { entries.append(.separator) }
            entries += items.map(ButtonMenu.overflowEntry(of:))
        }
        return entries
    }
}
