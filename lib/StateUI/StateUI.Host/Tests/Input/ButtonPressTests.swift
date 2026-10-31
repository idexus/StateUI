// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A press on a view that hears taps, as a button takes one on every host: lit while it stands over the view, out
/// as it leaves and lit again as it comes back; a tap where it lets go over the view, nothing where it lets go away
/// or is taken.
final class ButtonPressTests: XCTestCase {
    func testAPressLetGoOverTheViewTaps() {
        var press = ButtonPress()
        XCTAssertEqual(press.step(.began, over: true), [.lit])
        XCTAssertEqual(press.step(.changed, over: true), [])
        XCTAssertEqual(press.step(.ended, over: true), [.out, .tapped])
    }

    func testAPressLetGoAwayTapsNothing() {
        var press = ButtonPress()
        _ = press.step(.began, over: true)
        XCTAssertEqual(press.step(.changed, over: false), [.out], "out as it leaves")
        XCTAssertEqual(press.step(.ended, over: false), [], "let go away: nothing")
    }

    func testAPressThatComesBackTaps() {
        var press = ButtonPress()
        _ = press.step(.began, over: true)
        _ = press.step(.changed, over: false)
        XCTAssertEqual(press.step(.changed, over: true), [.lit], "lit again as it comes back")
        XCTAssertEqual(press.step(.ended, over: true), [.out, .tapped])
    }

    func testAPressTakenTapsNothing() {
        var press = ButtonPress()
        _ = press.step(.began, over: true)
        XCTAssertEqual(press.step(.cancelled, over: true), [.out], "a scroll or a drag took it")
        XCTAssertEqual(press.step(.ended, over: true), [], "no press stands")
    }

    /// A finger's press in a scroller lights the view only once it has stood a moment (`scrollerWait`), as iOS keeps
    /// a touch from a list's rows while it may still begin a scroll.
    func testAPressInAScrollerLightsOnlyAfterTheWait() {
        var press = ButtonPress()
        XCTAssertEqual(press.step(.began, over: true, waits: true, at: 0), [], "not lit at once")
        XCTAssertEqual(press.paced(now: 0.1), [], "still waiting")
        XCTAssertEqual(press.paced(now: ButtonPress.scrollerWait), [.lit], "lit after the wait")
        XCTAssertEqual(press.step(.ended, over: true), [.out, .tapped])
    }

    func testAScrollTakingAWaitingPressLightsNothing() {
        var press = ButtonPress()
        _ = press.step(.began, over: true, waits: true, at: 0)
        XCTAssertEqual(press.step(.cancelled, over: true), [], "a scroll took it before it was lit")
        XCTAssertEqual(press.paced(now: 1), [], "nothing waits")
    }

    func testAQuickTapInAScrollerLightsAsItTaps() {
        var press = ButtonPress()
        _ = press.step(.began, over: true, waits: true, at: 0)
        XCTAssertEqual(press.step(.ended, over: true), [.lit, .out, .tapped], "lit as it lets go, and tapped")
    }

    func testAFingerStandsOverAViewALittleBeyondItsEdge() {
        let size = LayoutSize(width: 100, height: 40)
        XCTAssertTrue(ButtonPress.isOver(Point(x: 50, y: 48), in: size, byFinger: true), "a finger's breadth")
        XCTAssertFalse(ButtonPress.isOver(Point(x: 50, y: 60), in: size, byFinger: true))
        XCTAssertFalse(ButtonPress.isOver(Point(x: 50, y: 41), in: size, byFinger: false), "a mouse's edge is the view's")
        XCTAssertTrue(ButtonPress.isOver(Point(x: 0, y: 40), in: size, byFinger: false))
    }
}
