// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

/// Where a view stands, as its handler hears it.
final class WinUIFrameReportTests: XCTestCase {
    /// A view says nothing of where it stands before a layout places it: the first report its handler hears is
    /// where it is laid out.
    func testAViewSaysNothingBeforeItIsLaidOut() {
        onUIThread {
            let heard = Received<[Double]>()
            let host = WinUIRenderer.running {
                VStack {
                    ColorBox(.steelBlue).width(120).height(60)
                        .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.settle { !heard.values.isEmpty }

            XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 0, 120, 60])
        }
    }

    /// A view that joins a shown page says nothing before its layout either: a display frame comes before the
    /// layout pass that places it.
    func testAViewThatJoinsSaysNothingBeforeItIsLaidOut() {
        onUIThread {
            let heard = Received<[Double]>()
            let shown = State(wrappedValue: false)
            let host = WinUIRenderer.running {
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
            shown.wrappedValue = true
            host.settle { heard.values.count >= 2 || heard.values.first?[2] == 120 }

            XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 20, 120, 60])
        }
    }

    /// WinUI's compositor moves a list's rows and lays nothing out: a view in a row says where it stands once the
    /// list has moved under it, as when the list is scrolled to an item already made.
    func testAViewInAListSaysWhereItStandsOnceTheListMoved() throws {
        try onUIThread {
            let heard = Received<[Double]>()
            let host = WinUIRenderer.running {
                VStack {
                    ItemsView(0..<100) { item in
                        ColorBox(item == 2 ? .red : .blue).width(120).height(60)
                            .onEvent(ViewContract.frameChanged) { if item == 2 { heard.values.append($0) } }
                    }
                    .width(200).height(300)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let list = try XCTUnwrap(host.views(WinUIItemsView.self).first)
            host.settle { !heard.values.isEmpty }
            let before = try XCTUnwrap(heard.values.last)

            // A list asked to move before its first frames are composed stays: asked until it starts moving.
            host.settle {
                if list.standingForTesting.offset.y > 0 { return true }
                list.scroll(to: "5", anchor: .nearest)
                return false
            }
            host.settle { list.standingForTesting.offset.y == 60 && heard.values.last?[5] == before[5] - 60 }

            XCTAssertEqual(list.standingForTesting.offset.y, 60, "item 5 brought wholly into view")
            XCTAssertEqual(heard.values.last?[5], before[5] - 60, "60 higher in its window")
            XCTAssertEqual(heard.values.last.map { Array($0.prefix(4)) }, Array(before.prefix(4)), "where it was in its cell")
        }
    }
}
