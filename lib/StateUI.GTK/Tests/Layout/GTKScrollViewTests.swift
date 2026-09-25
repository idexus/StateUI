// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIGTK
import StateUIHostConformance
import XCTest

final class GTKScrollViewTests: XCTestCase {
    /// The content takes the scroller's width, and its own height, however tall.
    func testAScrollerDownHoldsItsContentToItsWidth() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                ScrollView {
                    VStack { Label("tall").height(2000) }.padding(10)
                }
            }
            let scroll = try XCTUnwrap(host.views(GTKScrollView.self).first).frame

            let stack = try XCTUnwrap(host.views(GTKStackView.self).first)
            XCTAssertTrue(stack.frame == (0, 0, scroll.width, 2020), "\(stack.frame) in \(scroll)")
        }
    }

    /// A scroller shows its content through its viewport: what is scrolled away is cut off at its edges, where any
    /// other StateUI layout draws past them.
    func testAScrollerCutsItsContentOffAtItsEdges() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    ScrollView { ColorBox(.red).height(2000) }.height(100)
                }
                .height(300)
                .verticalAlignment(.start)
            }
            let stack = try XCTUnwrap(host.views(GTKStackView.self).first)

            XCTAssertEqual(stack.pixels(at: [(5, 50), (5, 150)]), [0xFFFF_0000, 0], "red inside, nothing below")
        }
    }

    func testAScrollerAcrossLeavesItsContentItsOwnWidth() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                ScrollView {
                    Label("wide").width(3000).height(40)
                }
                .orientation(.horizontal)
                .height(100)
            }

            let label = try XCTUnwrap(host.views(GTKLabelView.self).first)
            XCTAssertTrue(label.frame == (0, 30, 3000, 40), "\(label.frame)")
        }
    }

    /// A write moves GTK's scroller there; one past the end stops at the end.
    func testAnOffsetTheTreeWritesMovesTheScrollerWithinReach() throws {
        try onUIThread {
            let offset = State(wrappedValue: Point(0, 0))
            let heard = Received<Double>()
            let host = GTKRenderer.running(reducesMotion: true) {
                VStack {
                    Button("Down").onClicked { offset.wrappedValue = Point(0, 300) }
                    Button("Past").onClicked { offset.wrappedValue = Point(0, 5000) }
                    ScrollView { Label("tall").height(2000) }
                        .scrollOffset(offset.projectedValue)
                        .onEvent(ScrollViewContract.scrollYChanged) { y in heard.values.append(y) }
                        .height(500)
                }
            }
            let buttons = host.views(GTKButtonView.self)
            let scroll = try XCTUnwrap(host.views(GTKScrollView.self).first)

            buttons[0].click()
            host.settle { scroll.offset == Point(0, 300) }
            XCTAssertEqual(scroll.offset, Point(0, 300))
            XCTAssertEqual(scroll.scroller.standing.offset, Point(0, 300))

            buttons[1].click()
            host.settle { scroll.offset == Point(0, 1500) }
            XCTAssertEqual(scroll.offset, Point(0, 1500))
            XCTAssertEqual(heard.values, [], "the program's move is not heard as the user's")
        }
    }

    /// GTK moves the scroller: nothing is said until the display's frame, then the state and the handler hear
    /// where it went, and once it has stood still long enough it rests, once.
    func testTheUsersScrollingReachesItsStateOnTheFrameAndRestsOnce() throws {
        try onUIThread {
            let clock = TestClock()
            let offset = State(wrappedValue: Point(0, 0))
            let heard = Received<Double>()
            let rests = Received<Int>()
            let host = GTKRenderer.running(clock: clock) {
                ScrollView { Label("tall").height(2000) }
                    .scrollOffset(offset.projectedValue)
                    .onEvent(ScrollViewContract.scrollYChanged) { y in heard.values.append(y) }
                    .onScrollStopped { rests.values.append(1) }
                    .height(500)
            }
            let scroll = try XCTUnwrap(host.views(GTKScrollView.self).first)

            scroll.scroller.move(to: Point(0, 200))
            host.settle { scroll.offset == Point(0, 200) }
            XCTAssertEqual(heard.values, [], "said on the display's frame")

            clock.now = 16
            host.frame()
            XCTAssertEqual(heard.values, [200])
            XCTAssertEqual(offset.projectedValue.journey.value, Point(0, 200))

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

    /// A scroller that leaves the tree takes its document out of GTK's viewport and lets go of every view in it.
    func testAScrollerThatLeavesLetsGoOfItsDocument() throws {
        try onUIThread {
            let shown = State(wrappedValue: true)
            let host = GTKRenderer.running {
                VStack {
                    Button("Hide").onClicked { shown.wrappedValue = false }
                    if shown.wrappedValue {
                        ScrollView { Label("inside").height(400) }.height(100)
                    }
                }
            }
            let before = GTKView.liveCount
            XCTAssertEqual(host.views(GTKScrollView.self).count, 1)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            _ = host.core.runJobs()
            GTKTestHost.pump(0.05)

            XCTAssertEqual(host.views(GTKScrollView.self).count, 0)
            XCTAssertEqual(GTKView.liveCount, before - 5, "the scroll view, its scroller, document and stack, the label")
        }
    }

    /// A scroller outlines itself on its shape and cuts what it shows to that shape.
    func testAScrollerOutlinesItselfAndCutsWhatItShowsToItsShape() throws {
        try onUIThread {
            let host = GTKRenderer.running {
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

            let scroll = try XCTUnwrap(host.views(GTKScrollView.self).first)
            XCTAssertEqual(
                scroll.pixels(at: [(50, 0.5), (50, 40), (0.5, 0.5)]), [0xFF00_00FF, 0xFFFF_0000, 0],
                "the outline at the top edge, the content inside, the corner cut")
        }
    }
}
