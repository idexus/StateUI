// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where a page's bottom bar stands and what it leaves the page, the same on every host: as tall as it lays out, its
/// foot on the safe area's - on the keyboard while one shows, else above a phone's home indicator - and its ground out
/// to the room's sides and down to its foot.
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@_spi(Host) public struct BottomBarPlace: Equatable, Sendable {
    /// Where the bar's view stands: across the safe area, as tall as it lays out, its foot on the safe area's.
    public let bar: Rect

    /// What the bar stands on: its place out to the room's sides and down to the room's foot.
    public let ground: Rect

    /// The page's safe area, the bar standing over its foot - where a host's bars stand over the page.
    public let safe: Rect

    /// The room above the bar - where a host's bars stand beside the page, the whole room its content has.
    public let above: Rect

    /// How thick the blur under a hard edge is, where a host draws it: the rows show through it blurred, not hidden.
    public static let blur = Blur.Thickness.regular

    /// How much of the page's own color tints that blur, so the rows blur in the page's hue.
    public static let tint = 0.5

    /// Whether anything of a page stands under its bottom bar, so the bar shows its edge (`ScrollEdge`) rather than
    /// stand on the page: nothing where the content stands clear of the room's
    /// foot (`contentRunsUnder` false); where it runs under, its scroller's rows while they stand short of their end
    /// - at its end the last row stands clear above the bar - and anything else it holds always.
    /// Design: docs/design/host/layout.md#a-bar-at-the-foot
    public static func covers(contentRunsUnder: Bool, scroller: (offset: Point, reach: Point)?) -> Bool {
        guard contentRunsUnder else { return false }
        guard scroller != nil else { return true }
        return continues(scroller: scroller)
    }

    /// Whether a page's rows go on past its bottom bar - under it, or beyond its top where it stands beside the page -
    /// so the bar shows its edge: its scroller's, while they stand short of their end; none for no scroller.
    /// Design: docs/design/host/layout.md#a-bar-at-the-foot
    public static func continues(scroller: (offset: Point, reach: Point)?) -> Bool {
        guard let scroller else { return false }
        return scroller.offset.y < scroller.reach.y - 0.5
    }

    /// The place of a bar `height` tall at the foot of a page whose safe area is `safe` in the room `whole`; never
    /// taller than the safe area.
    public init(height: Double, safe: Rect, whole: Rect) {
        let height = min(max(height, 0), safe.height)
        let top = safe.y + safe.height - height
        bar = Rect(x: safe.x, y: top, width: safe.width, height: height)
        ground = Rect(x: whole.x, y: top, width: whole.width, height: max(0, whole.y + whole.height - top))
        self.safe = Rect(x: safe.x, y: safe.y, width: safe.width, height: safe.height - height)
        above = Rect(x: whole.x, y: whole.y, width: whole.width, height: max(0, top - whole.y))
    }
}
