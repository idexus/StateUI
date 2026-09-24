// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidScrollViewTests: XCTestCase {
    static var allTests: [(String, (AndroidScrollViewTests) -> () throws -> Void)] {
        [
            ("testAScrollerDownHoldsItsContentToItsWidth", testAScrollerDownHoldsItsContentToItsWidth),
            ("testAScrollerCutsItsContentOffAtItsEdges", testAScrollerCutsItsContentOffAtItsEdges),
            ("testAScrollerAcrossLeavesItsContentItsOwnWidth", testAScrollerAcrossLeavesItsContentItsOwnWidth),
            ("testAnOffsetTheTreeWritesMovesTheScrollerWithinReach", testAnOffsetTheTreeWritesMovesTheScrollerWithinReach),
            ("testTheUsersScrollingReachesItsStateOnTheFrameAndRestsOnce", testTheUsersScrollingReachesItsStateOnTheFrameAndRestsOnce),
            ("testAViewSaysWhereItStandsOnTheFrameAfterALayout", testAViewSaysWhereItStandsOnTheFrameAfterALayout),
            ("testAScrollerOutlinesItselfAndCutsWhatItShowsToItsShape", testAScrollerOutlinesItselfAndCutsWhatItShowsToItsShape),
            ("testAScrollerScrollsInItsOwnDirection", testAScrollerScrollsInItsOwnDirection),
        ]
    }

    /// The content takes the scroller's width, and its own height, however tall.
    func testAScrollerDownHoldsItsContentToItsWidth() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                ScrollView {
                    VStack { Label("tall").height(2000) }.padding(10)
                }
            }
            host.layOut()

            let stack = try XCTUnwrap(host.views(AndroidStackView.self).first)
            XCTAssertTrue(stack.frame == (0, 0, 1080, 4040), "\(stack.frame)")
        }
    }

    /// A scroller shows its content through its viewport: what is scrolled away is cut off at its edges,
    /// where any other StateUI layout draws past them.
    func testAScrollerCutsItsContentOffAtItsEdges() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                ScrollView { Label("tall").height(2000) }
            }
            let scroll = try XCTUnwrap(host.views(AndroidScrollView.self).first)

            XCTAssertTrue(Java.callBool(scroll.reference, TestJava.getClipChildren))
        }
    }

    func testAScrollerAcrossLeavesItsContentItsOwnWidth() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                ScrollView {
                    Label("wide").width(1000).height(40)
                }
                .orientation(.horizontal)
                .height(100)
            }
            host.layOut()

            let label = try XCTUnwrap(host.views(AndroidLabelView.self).first)
            XCTAssertTrue(label.frame == (0, 60, 2000, 80), "\(label.frame)")
        }
    }

    /// A write moves Android's scroller there at once where motion is off; one past the end stops at the end.
    func testAnOffsetTheTreeWritesMovesTheScrollerWithinReach() throws {
        try onMainActor {
            let offset = State(wrappedValue: Point(0, 0))
            let host = AndroidRenderer.running(reducesMotion: true) {
                VStack {
                    Button("Down").onClicked { offset.wrappedValue = Point(0, 300) }
                    Button("Past").onClicked { offset.wrappedValue = Point(0, 5000) }
                    ScrollView { Label("tall").height(2000) }
                        .scrollOffset(offset.projectedValue)
                        .height(500)
                }
            }
            host.layOut()
            let buttons = host.views(AndroidButtonView.self)
            let scroll = try XCTUnwrap(host.views(AndroidScrollView.self).first)

            buttons[0].click()
            XCTAssertEqual(scroll.offset, Point(0, 300))
            XCTAssertEqual(Java.callInt(scroll.scrollers[0].reference, JavaAPI.getScrollY), 600)

            buttons[1].click()
            XCTAssertEqual(scroll.offset, Point(0, 1500))
        }
    }

    /// Android moves the scroller: nothing is said until the display's frame, then the state and the handler
    /// hear where it went, and once it has stood still long enough it rests, once.
    func testTheUsersScrollingReachesItsStateOnTheFrameAndRestsOnce() throws {
        try onMainActor {
            let clock = TestClock()
            let offset = State(wrappedValue: Point(0, 0))
            let heard = Received<Double>()
            let rests = Received<Int>()
            let host = AndroidRenderer.running(clock: clock) {
                ScrollView { Label("tall").height(2000) }
                    .scrollOffset(offset.projectedValue)
                    .onEvent(ScrollViewContract.scrollYChanged) { y in heard.values.append(y) }
                    .onScrollStopped { rests.values.append(1) }
                    .height(500)
            }
            host.layOut()
            let scroll = try XCTUnwrap(host.views(AndroidScrollView.self).first)

            Java.call(scroll.scrollers[0].reference, JavaAPI.scrollTo, .int(0), .int(200))
            XCTAssertEqual(heard.values, [], "said on the display's frame")

            clock.now = 16
            host.frame()
            XCTAssertEqual(heard.values, [100])
            XCTAssertEqual(offset.projectedValue.journey.value, Point(0, 100))

            clock.now = 100
            host.frame()
            XCTAssertEqual(rests.values, [])

            clock.now = 140
            host.frame()
            XCTAssertEqual(rests.values, [1])

            clock.now = 300
            host.frame()
            XCTAssertEqual(rests.values, [1], "said once")
        }
    }

    /// After a layout, a view whose frame the tree reads says where it stands in its parent on the next frame.
    /// A root in no window stands nowhere in one, so its place in the window is walked on a device.
    func testAViewSaysWhereItStandsOnTheFrameAfterALayout() {
        onMainActor {
            let clock = TestClock()
            let room = State(wrappedValue: Rect(0, 0, 0, 0))
            let reports = Received<[Double]>()
            let host = AndroidRenderer.running(clock: clock) {
                VStack {
                    Label("above").height(30)
                    Label("read")
                        .height(20)
                        .frame(room.projectedValue)
                        .onEvent(ViewContract.frameChanged) { numbers in reports.values.append(numbers) }
                }
                .padding(10)
            }
            host.layOut()
            host.laidOut()
            clock.now = 16
            host.frame()

            XCTAssertEqual(reports.values.map { Array($0.prefix(4)) }, [[10, 40, 520, 20]])
            XCTAssertEqual(room.wrappedValue, Rect(10, 40, 520, 20))

            host.laidOut()
            clock.now = 32
            host.frame()
            XCTAssertEqual(reports.values.count, 1, "a frame that did not move says nothing")
        }
    }

    /// A scroller outlines itself on its shape and cuts what it shows to that shape.
    func testAScrollerOutlinesItselfAndCutsWhatItShowsToItsShape() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                ScrollView {
                    ColorBox(.red).height(400)
                }
                .padding(10)
                .shape(.roundedRectangle(20))
                .stroke(Color("#0000FF"))
                .strokeWidth(2)
                .width(100)
                .height(80)
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.layOut()

            let scroll = try XCTUnwrap(host.views(AndroidScrollView.self).first)
            XCTAssertEqual(scroll.pixels(at: [(100, 1)]), [0xFF00_00FF], "the outline at the top edge")
            XCTAssertTrue(Java.callBool(scroll.reference, TestJava.getClipToOutline))
            XCTAssertEqual(scroll.outlineRadius, 40, accuracy: 0.01)
        }
    }

    /// A scroller scrolls in its element's direction whatever the activity's: one told left to right starts at
    /// its first column under a page laid out right to left, and one right to left starts at its end.
    func testAScrollerScrollsInItsOwnDirection() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    ScrollView { Label("code") }.orientation(.horizontal).layoutDirection(.leftToRight)
                    ScrollView { Label("words") }.orientation(.horizontal)
                }
                .layoutDirection(.rightToLeft)
            }
            host.layOut()

            let directions = host.views(AndroidScrollView.self).map { scroll in
                Java.callInt(scroll.scrollers[0].reference, TestJava.getLayoutDirection)
            }
            XCTAssertEqual(directions, [0, 1], "left to right, then right to left")
        }
    }
}
