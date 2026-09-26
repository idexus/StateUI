// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidGridViewTests: XCTestCase {
    static var allTests: [(String, (AndroidGridViewTests) -> () throws -> Void)] {
        [
            ("testAGridStandsEachChildInItsCell", testAGridStandsEachChildInItsCell),
            ("testWordsThatWrapInAColumnMakeTheirRowTall", testWordsThatWrapInAColumnMakeTheirRowTall),
            ("testAProportionalRowTakesWhatTheOthersLeave", testAProportionalRowTakesWhatTheOthersLeave),
        ]
    }

    /// A fixed and a proportional column, two automatic rows, the spacing, the padding and a span, at two pixels a point.
    func testAGridStandsEachChildInItsCell() {
        onMainActor {
            let host = AndroidRenderer.running {
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

            host.layOut(width: 1080, height: 1920)

            let labels = host.views(AndroidLabelView.self)
            XCTAssertEqual(labels.count, 3)
            XCTAssertTrue(labels[0].frame == (20, 20, 100, 40), "\(labels[0].frame)")
            XCTAssertTrue(labels[1].frame == (230, 20, 830, 40), "\(labels[1].frame)")
            XCTAssertTrue(labels[2].frame == (1000, 80, 60, 80), "\(labels[2].frame)")
        }
    }

    /// A card's words wrap in its proportional column, and their row, the grid and the card are as tall as the
    /// words stand.
    func testWordsThatWrapInAColumnMakeTheirRowTall() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    ZStack {
                        Grid {
                            Label("one two three four five six seven eight nine ten eleven twelve").maximumLines(2)
                            Label("›").gridColumn(1)
                        }
                        .columns(.fill, .auto)
                    }
                    .width(150)
                    .horizontalAlignment(.start)
                    Label("one").horizontalAlignment(.start)
                }
            }
            host.layOut()

            let labels = host.views(AndroidLabelView.self)
            let line = labels[2].frame.height
            XCTAssertGreaterThan(labels[0].frame.height, line * 3 / 2, "two lines, \(labels[0].frame)")
            XCTAssertLessThan(labels[0].frame.height, line * 5 / 2, "no more than two")
            let card = try XCTUnwrap(host.views(AndroidZStackView.self).first)
            XCTAssertGreaterThanOrEqual(card.frame.height, labels[0].frame.height)
        }
    }

    /// The gallery's menu: a header and a footer keep their height, and the row between them takes the rest.
    func testAProportionalRowTakesWhatTheOthersLeave() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Grid {
                    Label("head").height(30)
                    ColorBox(.red).gridRow(1)
                    Label("foot").height(20).gridRow(2)
                }
                .rows(.auto, .fill, .auto)
            }

            host.layOut(width: 1080, height: 1920)

            let box = try XCTUnwrap(host.views(AndroidColorBoxView.self).first)
            XCTAssertTrue(box.frame == (0, 60, 1080, 1820), "\(box.frame)")
        }
    }
}
