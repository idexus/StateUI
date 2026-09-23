// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidLabelViewTests: XCTestCase {
    static var allTests: [(String, (AndroidLabelViewTests) -> () throws -> Void)] {
        [
            ("testALabelsSpansAreRunsOfItsWords", testALabelsSpansAreRunsOfItsWords),
            ("testALabelShowsAsManyLinesAsItsBreakAllows", testALabelShowsAsManyLinesAsItsBreakAllows),
            ("testALabelsCaseAndLetterSpacingAreItsOwn", testALabelsCaseAndLetterSpacingAreItsOwn),
        ]
    }

    /// The runs' words are the label's, one after another, and a larger run makes the line taller.
    func testALabelsSpansAreRunsOfItsWords() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Label()
                        .spans {
                            TextSpan("small ").textColor(.red).fontSize(12)
                            TextSpan("large").fontSize(36).fontAttributes(.bold)
                        }
                        .horizontalAlignment(.start)
                    Label("small large").fontSize(12).horizontalAlignment(.start)
                }
            }
            host.layOut()

            let labels = host.views(AndroidLabelView.self)
            XCTAssertEqual(labels[0].text, "small large")
            XCTAssertGreaterThan(labels[0].frame.height, labels[1].frame.height * 3 / 2)
        }
    }

    /// The same words, too long for one line: wrapping shows them all, two lines at most shows two, and a
    /// truncated line one.
    func testALabelShowsAsManyLinesAsItsBreakAllows() {
        onMainActor {
            let words = "one two three four five six seven eight nine ten eleven twelve"
            let host = AndroidRenderer.running {
                VStack {
                    Label(words).width(100)
                    Label(words).width(100).maximumLines(2)
                    Label(words).width(100).lineBreak(.tailTruncation)
                }
            }
            host.layOut()

            let lines = host.views(AndroidLabelView.self).map { Java.callInt($0.reference, TestJava.getLineCount) }
            XCTAssertGreaterThan(lines[0], 2)
            let heights = host.views(AndroidLabelView.self).map(\.frame.height)
            XCTAssertGreaterThan(heights[0], heights[1])
            XCTAssertGreaterThan(heights[1], heights[2])
        }
    }

    /// Upper case throughout, and letter spacing in points drawn as Android's share of the text size.
    func testALabelsCaseAndLetterSpacingAreItsOwn() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Label("Hello").textCase(.uppercase).fontSize(20).characterSpacing(2)
            }

            let label = try XCTUnwrap(host.views(AndroidLabelView.self).first)
            XCTAssertEqual(label.text, "HELLO")
            let size = Java.callFloat(label.reference, JavaAPI.getTextSize)
            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getLetterSpacing), 4 / size, accuracy: 0.0001)
        }
    }
}
