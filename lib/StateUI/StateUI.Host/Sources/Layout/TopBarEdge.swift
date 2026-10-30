// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// When a page's top bar shows its edge, the same on every host that draws it: the bar stands on what is under it
/// while nothing of the page is, and shows its edge while the page's rows pass under it.
/// Design: docs/design/host/layout.md#a-bar-at-the-top
@_spi(Host) public enum TopBarEdge {
    /// Whether anything of a page stands under its top bar: nothing where the content stands clear of the room's top
    /// (`contentRunsUnder` false); where it runs under, its scroller's rows once they scroll past their start - at
    /// their start the first row stands clear below the bar - and anything else it holds always.
    public static func covers(contentRunsUnder: Bool, scrollerOffset: Point?) -> Bool {
        guard contentRunsUnder else { return false }
        guard let scrollerOffset else { return true }
        return scrollerOffset.y > 0.5
    }
}
