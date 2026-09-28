// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import StateUIConformance
import XCTest

final class WinUIScrollViewTests: XCTestCase {
    /// A scroller shows its content through its viewport: what is scrolled away is cut off at its edges, where any
    /// other StateUI layout draws past them.
    func testAScrollerCutsItsContentOffAtItsEdges() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    ScrollView { ColorBox(.red).height(2000) }.height(100)
                }
                .height(300)
                .verticalAlignment(.start)
            }
            let stack = try XCTUnwrap(host.views(WinUIStackView.self).first)

            XCTAssertEqual(stack.pixels(at: [(5, 50), (5, 150)]), [0xFFFF_0000, 0], "red inside, nothing below")
        }
    }

    /// A scroller outlines itself on its shape and cuts what it shows to that shape.
    func testAScrollerOutlinesItselfAndCutsWhatItShowsToItsShape() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
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

            let scroll = try XCTUnwrap(host.views(WinUIScrollView.self).first)
            XCTAssertEqual(
                scroll.pixels(at: [(50, 0.5), (50, 40), (0.5, 0.5)]), [0xFF00_00FF, 0xFFFF_0000, 0],
                "the outline at the top edge, the content inside, the corner cut")
        }
    }
}
