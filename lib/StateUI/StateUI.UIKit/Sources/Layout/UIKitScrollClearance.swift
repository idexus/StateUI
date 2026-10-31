// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a page's scroller keeps clear of the bars over it - a ScrollView's, an ItemsView's - on UIKit's scroll view:
/// the clearance as its content inset and its indicators', its offsets counted from its first content clear, and its
/// end kept where the clearance changes (`ScrollArithmetic.keptAtEnd`). A class: moving the scroller tells its
/// delegate at once, which reads where it stands while the clearance is being kept.
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
final class UIKitScrollClearance {
    /// What the scroller keeps clear on each edge.
    private(set) var clearance = Clearance.none

    /// Keeps `clearance` clear on `scroller`, which stands where it stood - or at its end still where it stood at its
    /// end, a move of its own told as the user's is; `programs` makes the standing move the program's write.
    func keep(_ clearance: Clearance, on scroller: UIScrollView, programs: (() -> Void) -> Void) {
        guard clearance != self.clearance else { return }
        let (standing, before) = (standing(of: scroller), reach(of: scroller, keeping: self.clearance))
        inset(clearance, on: scroller)
        let native = native(of: standing)
        programs { scroller.contentOffset = native }
        if let end = ScrollArithmetic.keptAtEnd(standing, reach: before, now: reach(of: scroller, keeping: clearance)) {
            scroller.contentOffset = self.native(of: end)
        }
    }

    /// Takes `clearance` as `scroller`'s insets alone, its offset left as it is - a glide under way going on.
    func inset(_ clearance: Clearance, on scroller: UIScrollView) {
        self.clearance = clearance
        let (top, left, bottom, right) = (clearance.top, clearance.left, clearance.bottom, clearance.right)
        scroller.contentInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        scroller.verticalScrollIndicatorInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        scroller.horizontalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: left, bottom: 0, right: right)
    }

    /// The farthest `scroller` stands keeping `clearance` clear: its content and the clearance past its viewport.
    func reach(of scroller: UIScrollView, keeping clearance: Clearance) -> Point {
        Point(
            x: max(0, scroller.contentSize.width + clearance.left + clearance.right - scroller.bounds.width),
            y: max(0, scroller.contentSize.height + clearance.top + clearance.bottom - scroller.bounds.height))
    }

    /// The toolkit's offset for the scroller to stand at `offset`, counted from its first content kept clear.
    func native(of offset: Point) -> CGPoint {
        let native = SafeAreaArithmetic.native(offset: offset, clearance: clearance)
        return CGPoint(x: native.x, y: native.y)
    }

    /// Where `scroller` stands as the toolkit shows it, counted from its first content clear of what it keeps clear.
    func standing(of scroller: UIScrollView) -> Point {
        SafeAreaArithmetic.offset(
            native: Point(x: scroller.contentOffset.x, y: scroller.contentOffset.y), clearance: clearance)
    }
}

/// A view a page scrolls by - a ScrollView's, an ItemsView's: kept clear of the bars over it, its scroll view showing
/// the edge a bottom bar asks for.
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
protocol UIKitPageScroller: AnyObject {
    /// UIKit's scroll view it moves.
    var scroller: UIScrollView { get }

    /// Keeps `clearance` clear of what stands over it.
    func keepClear(_ clearance: Clearance)
}
#endif
