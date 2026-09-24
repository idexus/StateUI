// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUIGridViewTests: XCTestCase {
    /// A fixed and a proportional column, two automatic rows, the spacing, the padding and a span, in DIPs.
    func testAGridStandsEachChildInItsCell() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                Grid {
                    Label("A").width(50).height(20).horizontalAlignment(.start)
                    Label("B").height(20).gridColumn(1)
                    Label("C").width(30).height(40).gridRow(1).gridColumnSpan(2).horizontalAlignment(.end)
                }
                .columns(.fixed(100), .fill)
                .rows(.auto, .auto)
                .rowSpacing(10)
                .columnSpacing(5)
                .padding(10)
            }
            let width = try XCTUnwrap(host.views(WinUIGridView.self).first).frame.width

            let labels = host.views(WinUILabelView.self)
            XCTAssertEqual(labels.count, 3)
            XCTAssertTrue(labels[0].frame == (10, 10, 50, 20), "\(labels[0].frame)")
            XCTAssertTrue(labels[1].frame == (115, 10, width - 125, 20), "\(labels[1].frame)")
            XCTAssertTrue(labels[2].frame == (width - 40, 40, 30, 40), "\(labels[2].frame)")
        }
    }

    /// The gallery's menu: a header and a footer keep their height, and the row between them takes the rest.
    func testAProportionalRowTakesWhatTheOthersLeave() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                Grid {
                    Label("head").height(30)
                    ColorBox(.red).gridRow(1)
                    Label("foot").height(20).gridRow(2)
                }
                .rows(.auto, .fill, .auto)
            }
            let grid = try XCTUnwrap(host.views(WinUIGridView.self).first).frame

            let box = try XCTUnwrap(host.views(WinUIColorBoxView.self).first)
            XCTAssertTrue(box.frame == (0, 30, grid.width, grid.height - 50), "\(box.frame) in \(grid)")
        }
    }
}
