// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance
import XCTest

/// Where a view stands, as its handler hears it.
@MainActor
final class UIKitFrameReportTests: XCTestCase {
    /// A view says nothing of where it stands before a layout places it: the first report its handler hears is
    /// where it is laid out.
    @MainActor
    func testAViewSaysNothingBeforeItIsLaidOut() {
        let heard = Received<[Double]>()
        let host = UIKitRenderer.running {
            VStack {
                ColorBox(.steelBlue).width(120).height(60)
                    .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { host.finish() }
        host.settle { !heard.values.isEmpty }

        XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 0, 120, 60])
    }

    /// A view that joins a shown page says nothing before its layout either: a display frame comes before the
    /// layout pass that places it.
    @MainActor
    func testAViewThatJoinsSaysNothingBeforeItIsLaidOut() {
        let heard = Received<[Double]>()
        let shown = State(wrappedValue: false)
        let host = UIKitRenderer.running {
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
        defer { host.finish() }
        shown.wrappedValue = true
        host.runtime.pump.turn()
        host.frame()
        host.settle { heard.values.count >= 2 || heard.values.first?[2] == 120 }

        XCTAssertEqual(heard.values.first.map { Array($0.prefix(4)) }, [0, 20, 120, 60])
    }

    /// The safe area is where a page's content may stand: under a stack's bar too, not the status bar alone - a view
    /// at the top corner of its page reads nothing from it.
    @MainActor
    func testAViewAtItsPagesTopCornerStandsAtTheSafeAreasCorner() throws {
        let heard = Received<[Double]>()
        let host = UIKitRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                VStack {
                    ColorBox(.steelBlue).width(120).height(60)
                        .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
                .title("Top")
            } destination: { _ in Text("Below") }
        }
        defer { host.finish() }
        host.settle { (heard.values.last?[5] ?? 0) > 0 }

        let report = try XCTUnwrap(heard.values.last)
        XCTAssertGreaterThan(report[5], 60, "under the status bar and the stack's bar")
        XCTAssertEqual(Array(report[6...7]), [0, 0], "at the corner of the safe area")
    }

    /// A scroll moves what stands in the scroller: a view's place in the window is said again, though nothing laid
    /// it out anew - its place in its parent stays.
    @MainActor
    func testAScrollSaysWhereAViewStandsInTheWindow() throws {
        let heard = Received<[Double]>()
        let host = UIKitRenderer.running {
            ScrollView {
                VStack {
                    ColorBox(.steelBlue).width(120).height(60)
                        .onEvent(ViewContract.frameChanged) { heard.values.append($0) }
                    ColorBox(.firebrick).width(120).height(3000)
                }
                .horizontalAlignment(.start)
            }
        }
        defer { host.finish() }
        host.settle { !heard.values.isEmpty }
        let before = try XCTUnwrap(heard.values.last)
        let scroller = try XCTUnwrap(host.views(UIKitScrollView.self).first?.scroller)

        scroller.setContentOffset(CGPoint(x: 0, y: 100), animated: false)
        host.frame()
        host.settle { heard.values.last?[5] != before[5] }

        let after = try XCTUnwrap(heard.values.last)
        XCTAssertEqual(after[5], before[5] - 100, "its place in the window moved with the scroll")
        XCTAssertEqual(Array(after.prefix(4)), Array(before.prefix(4)), "its place in its parent stays")
    }

    /// A list's scroll moves its rows with no layout: a view in a row says where it stands once the list moved - by
    /// less than a row, so no row coming into view lays anything out.
    @MainActor
    func testAViewInAListSaysWhereItStandsOnceTheListMoved() throws {
        let heard = Received<[Double]>()
        let host = UIKitRenderer.running {
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
        defer { host.finish() }
        host.settle { !heard.values.isEmpty }
        let before = try XCTUnwrap(heard.values.last)
        let list = try XCTUnwrap(host.views(UIKitItemsView.self).first)

        list.collection.setContentOffset(CGPoint(x: 0, y: 30), animated: false)
        host.settle { heard.values.last?[5] != before[5] }

        let after = try XCTUnwrap(heard.values.last)
        XCTAssertEqual(after[5], before[5] - 30, "30 higher in its window")
        XCTAssertEqual(Array(after.prefix(4)), Array(before.prefix(4)), "where it was in its cell")
    }
}
