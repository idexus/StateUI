// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import XCTest

/// Where a view stands, as its handler hears it. A test's root stands in no window, so each layout is told as the
/// window's layout listener tells it - except where the window's own frames and traversals are what a test proves.
final class AndroidFrameReportTests: XCTestCase {
    static var allTests: [(String, (AndroidFrameReportTests) -> () throws -> Void)] {
        [
            ("testAViewSaysNothingBeforeItIsLaidOut", testAViewSaysNothingBeforeItIsLaidOut),
            ("testAViewThatJoinsSaysNothingBeforeItIsLaidOut", testAViewThatJoinsSaysNothingBeforeItIsLaidOut),
            ("testAViewInAListSaysWhereItStandsOnceTheListMoved", testAViewInAListSaysWhereItStandsOnceTheListMoved),
        ]
    }

    /// A view says nothing of where it stands before a layout places it: the first report its handler hears is
    /// where it is laid out.
    func testAViewSaysNothingBeforeItIsLaidOut() {
        onMainActor {
            let heard = Received<[Double]>()
            let host = AndroidRenderer.running {
                VStack {
                    ColorBox(.steelBlue).width(120).height(60)
                        .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.runtime.frames.laidOut()
            host.frame()
            host.layOut()
            host.runtime.frames.laidOut()
            host.frame()
            host.settle { !heard.values.isEmpty }

            XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 0, 120, 60])
        }
    }

    /// A view that joins a shown page says nothing before its layout either: a display frame comes before the
    /// layout pass that places it.
    func testAViewThatJoinsSaysNothingBeforeItIsLaidOut() {
        onMainActor {
            let heard = Received<[Double]>()
            let shown = State(wrappedValue: false)
            let host = AndroidRenderer.running {
                VStack {
                    Text("above").height(20)
                    if shown.wrappedValue {
                        ColorBox(.steelBlue).width(120).height(60)
                            .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
                    }
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.layOut()
            shown.wrappedValue = true
            host.runtime.pump.turn()
            host.runtime.frames.laidOut()
            host.frame()
            host.layOut()
            host.runtime.frames.laidOut()
            host.frame()
            host.settle { heard.values.count >= 2 || heard.values.first?[2] == 120 }

            XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 20, 120, 60])
        }
    }

    /// A list's scroll moves its rows with no layout: a view in a row says where it stands once the list moved - by
    /// less than a row, so no row coming into view lays anything out. In the activity's window, on the display's
    /// frames, the list alone telling it: the driver's root has no window listener.
    func testAViewInAListSaysWhereItStandsOnceTheListMoved() throws {
        try onMainActor {
            let heard = Received<[Double]>()
            let driver = AndroidDriver()
            _ = driver.start(clock: nil, reducesMotion: false) {
                VStack {
                    ItemsView(0..<100) { item in
                        ColorBox(item == 2 ? .firebrick : .steelBlue).width(120).height(60)
                            .onEvent(ViewContract.frameChanged) { if item == 2 { heard.values.append($0) } }
                    }
                    .width(200).height(300)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            defer { driver.finish() }
            let host = try XCTUnwrap(driver.renderer)
            Self.settleInTheWindow(host) { !heard.values.isEmpty }
            let before = try XCTUnwrap(heard.values.last)
            let list = try XCTUnwrap(host.views(AndroidItemsView.self).first)

            list.scrollForTesting(to: Point(x: 0, y: 30))
            Self.settleInTheWindow(host) { heard.values.last?[5] != before[5] }

            let after = try XCTUnwrap(heard.values.last)
            XCTAssertEqual(after[5], before[5] - 30, "30 higher in its window")
            XCTAssertEqual(Array(after.prefix(4)), Array(before.prefix(4)), "where it was in its cell")
        }
    }

    /// Runs the window's messages - its traversals, the display's frames - and the host's turns until `done` holds.
    @MainActor
    private static func settleInTheWindow(_ host: AndroidRenderer, until done: () -> Bool) {
        for _ in 0..<150 where !done() {
            TestWindow.run(for: 10)
            host.runtime.pump.turn()
        }
    }
}
