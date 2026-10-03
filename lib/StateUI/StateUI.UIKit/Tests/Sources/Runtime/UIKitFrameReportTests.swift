// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance
import XCTest

/// Where a view stands, as its handler hears it.
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
}
