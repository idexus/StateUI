// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import XCTest

final class GTKGridViewTests: XCTestCase {
    /// A fixed and a proportional column, two automatic rows, the spacing, the padding and a span, in logical pixels.
    func testAGridStandsEachChildInItsCell() throws {
        try onUIThread {
            let host = GTKRenderer.running {
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
            let width = try XCTUnwrap(host.views(GTKGridView.self).first).frame.width

            let labels = host.views(GTKLabelView.self)
            XCTAssertEqual(labels.count, 3)
            XCTAssertTrue(labels[0].frame == (10, 10, 50, 20), "\(labels[0].frame)")
            XCTAssertTrue(labels[1].frame == (115, 10, width - 125, 20), "\(labels[1].frame)")
            XCTAssertTrue(labels[2].frame == (width - 40, 40, 30, 40), "\(labels[2].frame)")
        }
    }

    /// Words with a margin in a cell are measured at the cell's width less the margin, once: on one line, as tall
    /// as without it, and the pass settles.
    func testWordsWithAMarginStandOnOneLineInTheirCell() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Grid { Label("Waiting for the first render of this scene") }
                    Grid { Label("Waiting for the first render of this scene").margin(8, 4) }
                }
                .horizontalAlignment(.start)
            }
            let labels = host.views(GTKLabelView.self)
            XCTAssertEqual(labels.count, 2)
            XCTAssertEqual(labels[1].frame.height, labels[0].frame.height, "on one line")
            XCTAssertEqual(labels[1].frame.y, 4)
        }
    }

    /// The gallery's menu: a header and a footer keep their height, and the row between them takes the rest.
    func testAProportionalRowTakesWhatTheOthersLeave() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                Grid {
                    Label("head").height(30)
                    ColorBox(.red).gridRow(1)
                    Label("foot").height(20).gridRow(2)
                }
                .rows(.auto, .fill, .auto)
            }
            let grid = try XCTUnwrap(host.views(GTKGridView.self).first).frame

            let box = try XCTUnwrap(host.views(GTKColorBoxView.self).first)
            XCTAssertTrue(box.frame == (0, 30, grid.width, grid.height - 50), "\(box.frame) in \(grid)")
        }
    }

    /// A child spanning two rows stands across both and the spacing between them.
    func testAChildSpanningRowsStandsAcrossThem() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                Grid {
                    ColorBox(.red).gridRowSpan(2)
                    Label("one").height(20).gridColumn(1)
                    Label("two").height(30).gridRow(1).gridColumn(1)
                }
                .columns(.fixed(20), .fill)
                .rows(.auto, .auto)
                .rowSpacing(10)
            }
            let box = try XCTUnwrap(host.views(GTKColorBoxView.self).first)

            XCTAssertTrue(box.frame == (0, 0, 20, 60), "\(box.frame)")
        }
    }
}
