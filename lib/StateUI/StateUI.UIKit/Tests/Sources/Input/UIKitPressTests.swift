// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@testable import StateUIUIKit
import XCTest

/// A press on a view that hears taps, as UIKit tells it.
@MainActor
final class UIKitPressTests: XCTestCase {
    /// A TOUCH CATCHING A SCROLLER STILL MOVING IS THE SCROLLER'S: it stops it, as every list on iOS is stopped, and
    /// presses no row in it - lit by nothing, tapping nothing; a row in a scroller at rest is pressed.
    func testATouchCatchingAMovingScrollerPressesNothing() {
        let (resting, moving) = (UIScrollView(), MovingScroller())
        let (row, rowInMotion) = (UIView(), UIView())
        resting.addSubview(row)
        moving.addSubview(rowInMotion)

        XCTAssertFalse(UIKitPressRecognizer.catchesAScroll(row), "a scroller at rest")
        XCTAssertTrue(UIKitPressRecognizer.catchesAScroll(rowInMotion), "a scroller slowing down from a throw")
    }

    /// A TOUCH CATCHING A SCROLLER SPRINGING BACK IS THE SCROLLER'S: its pan under way as the touch falls - a list a
    /// fraction of a point from its edge, still settling - takes the touch, and no row in it is pressed.
    func testATouchCatchingAScrollerSpringingBackPressesNothing() {
        let springing = SpringingScroller()
        let row = UIView()
        springing.addSubview(row)

        XCTAssertTrue(UIKitPressRecognizer.catchesAScroll(row))
    }
}

/// A scroller still slowing down from a throw.
private final class MovingScroller: UIScrollView {
    override var isDecelerating: Bool { true }
}

/// A scroller whose pan is under way, as one springing back from its edge catches the next touch.
private final class SpringingScroller: UIScrollView {
    override var panGestureRecognizer: UIPanGestureRecognizer { BeganPan() }
}

/// A pan already begun.
private final class BeganPan: UIPanGestureRecognizer {
    override var state: UIGestureRecognizer.State {
        get { .began }
        set {}
    }
}
