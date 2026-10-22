// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The room a platform gives a sheet on a wide screen: the least it stands at, the size it takes for a page asking
/// none, and the most - the window's room left around it.
@_spi(Host) public struct SheetRoom: Equatable, Sendable {
    /// The least a sheet stands at.
    public var least: LayoutSize
    /// The size a sheet takes for a page asking none.
    public var standard: LayoutSize
    /// The most a sheet stands at.
    public var most: LayoutSize

    public init(least: LayoutSize, standard: LayoutSize, most: LayoutSize) {
        self.least = least
        self.standard = standard
        self.most = most
    }
}

/// How large a sheet stands on a wide screen, the same on every host: as large as its page asks, held within the
/// platform's room; at the room's standard size where the page asks none.
/// Design: docs/design/host/pages.md#a-sheets-size
@_spi(Host) @MainActor public enum SheetSize {
    /// Whether `page`, the page a sheet presents, asks a size of its own: a page does, but for one holding a view
    /// that takes the room it is given (`NodeType.roomTakingTypes`); a stack, tabs and a split view never, as their
    /// pages come and go.
    public static func asks(_ page: MountedElement) -> Bool {
        var shown = page
        while shown.type == .anchor, let held = shown.arrangedChildren.first { shown = held }
        return shown.type == .page && !holdsARoomTaker(shown)
    }

    /// The size a sheet presenting `page` stands at in `room`: the page's natural size for the room's most width
    /// (`natural`), held within the room; the standard size, no larger than the most, where it asks none. A window
    /// smaller than the least - one not laid out yet - holds a sheet at the least.
    public static func size(of page: MountedElement, in room: SheetRoom, natural: (Double) -> LayoutSize) -> LayoutSize {
        let most = LayoutSize(
            width: max(room.most.width, room.least.width), height: max(room.most.height, room.least.height))
        let asking = asks(page)
        let asked = asking ? natural(most.width) : room.standard
        let least = asking ? room.least : LayoutSize(width: 0, height: 0)
        return LayoutSize(
            width: min(max(asked.width, least.width), most.width),
            height: min(max(asked.height, least.height), most.height))
    }

    private static func holdsARoomTaker(_ element: MountedElement) -> Bool {
        element.arrangedChildren.contains { NodeType.roomTakingTypes.contains($0.type) || holdsARoomTaker($0) }
    }
}
