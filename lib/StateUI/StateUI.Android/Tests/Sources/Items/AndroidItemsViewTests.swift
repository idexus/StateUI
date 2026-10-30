// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidItemsViewTests: XCTestCase {
    static var allTests: [(String, (AndroidItemsViewTests) -> () throws -> Void)] {
        [
            ("testAListCutsItsRowsAtItsEdges", testAListCutsItsRowsAtItsEdges),
            ("testAScrollToAnItemJustComeGlidesThere", testAScrollToAnItemJustComeGlidesThere),
        ]
    }

    /// A list cuts its rows off at its edges, as every platform's list does, though a StateUI layout lets its
    /// children draw past its own: a row scrolled half past the list's top shows nothing over the view above it.
    func testAListCutsItsRowsAtItsEdges() throws {
        try onMainActor {
            let driver = AndroidDriver()
            _ = driver.start(clock: nil, reducesMotion: false) {
                VStack {
                    Rectangle()
                        .fill(.white)
                        .width(200)
                        .height(60)
                    ItemsView(0..<100) { _ in
                        Rectangle()
                            .fill(.firebrick)
                            .width(200)
                            .height(60)
                    }
                        .width(200).height(300)
                }
                .spacing(0)
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            defer { driver.finish() }
            let host = try XCTUnwrap(driver.renderer)
            Self.settleInTheWindow(host)
            let list = try XCTUnwrap(host.views(AndroidItemsView.self).first)
            let above = try XCTUnwrap(host.views(AndroidShapeView.self).first)

            list.scrollForTesting(to: Point(x: 0, y: 30))
            Self.settleInTheWindow(host)

            // The first row stands from half the view above's height to half its own into the list.
            let (_, _, width, height) = above.frame
            XCTAssertEqual(Self.color(of: above, at: (width / 2, height * 3 / 4)), 0xFFFF_FFFF,
                           "the view above, not the row past the list's top")
        }
    }

    /// A scroll the program asks for to an item that has just come past the list's end - not laid out yet - glides
    /// there as the recycler glides over a distance, and reaches it: a message sent slides into view, never jumps.
    func testAScrollToAnItemJustComeGlidesThere() throws {
        try onMainActor {
            let numbers = State(wrappedValue: Array(0..<30))
            let driver = AndroidDriver()
            _ = driver.start(clock: nil, reducesMotion: false) {
                VStack {
                    Text("Rows")
                    ItemsView(numbers.wrappedValue) { Text("Row \($0)").fontSize(14).padding(10) }
                        .width(300).height(400)
                }
            }
            defer { driver.finish() }
            let host = try XCTUnwrap(driver.renderer)
            Self.settleInTheWindow(host)
            let list = try XCTUnwrap(host.views(AndroidItemsView.self).first)
            list.scrollForTesting(to: Point(x: 0, y: 10_000))
            Self.settleInTheWindow(host)
            let start = list.standing.offset.y

            numbers.wrappedValue.append(30)
            host.runtime.pump.turn()
            list.scroll(to: "30", anchor: .end)
            TestWindow.run(for: 50)
            XCTAssertLessThan(list.standing.offset.y, list.standing.reach.y - 1, "on its way, not there at once (from \(start))")

            Self.settleInTheWindow(host)
            XCTAssertEqual(list.standing.offset.y, list.standing.reach.y, accuracy: 1, "at the new item")
            XCTAssertGreaterThan(list.standing.offset.y, start + 1, "moved on to it")
        }
    }

    /// The color the window shows at `point` of the view's pixels, as ARGB (`TestPixels.colors`).
    @MainActor
    private static func color(of view: AndroidView, at point: (x: Int32, y: Int32)) -> UInt32 {
        Java.frame {
            let shown = Java.callStaticObject(
                AndroidDriver.testPixels, AndroidDriver.pixels, .object(view.reference),
                .object(Java.ints([point.x, point.y])))
            return shown.map { UInt32(bitPattern: Java.intsOf($0).first ?? 0) } ?? 0
        }
    }

    /// Runs the window's messages - its traversals, the display's frames - and the host's turns a while.
    @MainActor
    private static func settleInTheWindow(_ host: AndroidRenderer) {
        for _ in 0..<30 {
            TestWindow.run(for: 10)
            host.runtime.pump.turn()
        }
    }
}
