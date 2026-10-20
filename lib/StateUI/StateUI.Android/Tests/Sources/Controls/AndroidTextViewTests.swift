// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidTextViewTests: XCTestCase {
    static var allTests: [(String, (AndroidTextViewTests) -> () throws -> Void)] {
        [
            ("testATextsSpansAreRunsOfItsWords", testATextsSpansAreRunsOfItsWords),
            ("testATextShowsAsManyLinesAsItsBreakAllows", testATextShowsAsManyLinesAsItsBreakAllows),
            ("testWrappedWordsHeldToSomeLinesEndWithAnEllipsis", testWrappedWordsHeldToSomeLinesEndWithAnEllipsis),
            ("testATextsCaseAndLetterSpacingAreItsOwn", testATextsCaseAndLetterSpacingAreItsOwn),
            ("testABackgroundBrushIsDrawnAcrossTheView", testABackgroundBrushIsDrawnAcrossTheView),
            ("testALabelsWordsStandInTheThemesPrimaryColour", testALabelsWordsStandInTheThemesPrimaryColour),
        ]
    }

    /// The runs' words are the label's, one after another, and a larger run makes the line taller.
    func testATextsSpansAreRunsOfItsWords() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Text()
                        .spans {
                            TextSpan("small ").textColor(.red).fontSize(12)
                            TextSpan("large").fontSize(36).fontWeight(.bold)
                        }
                        .horizontalAlignment(.start)
                    Text("small large").fontSize(12).horizontalAlignment(.start)
                }
            }
            host.layOut()

            let labels = host.views(AndroidTextView.self)
            XCTAssertEqual(labels[0].text, "small large")
            XCTAssertGreaterThan(labels[0].frame.height, labels[1].frame.height * 3 / 2)
        }
    }

    /// The same words, too long for one line: wrapping shows them all, two lines at most shows two, and a
    /// truncated line one.
    func testATextShowsAsManyLinesAsItsBreakAllows() {
        onMainActor {
            let words = "one two three four five six seven eight nine ten eleven twelve"
            let host = AndroidRenderer.running {
                VStack {
                    Text(words).width(100)
                    Text(words).width(100).maximumLines(2)
                    Text(words).width(100).lineBreak(.tailTruncation)
                }
            }
            host.layOut()

            let lines = host.views(AndroidTextView.self).map { Java.callInt($0.reference, TestJava.getLineCount) }
            XCTAssertGreaterThan(lines[0], 2)
            let heights = host.views(AndroidTextView.self).map(\.frame.height)
            XCTAssertGreaterThan(heights[0], heights[1])
            XCTAssertGreaterThan(heights[1], heights[2])
        }
    }

    /// Wrapped words held to some lines end the last with an ellipsis; words free of a limit end with none, and a
    /// truncated line keeps its own.
    func testWrappedWordsHeldToSomeLinesEndWithAnEllipsis() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Text("Words held to two lines").maximumLines(2)
                    Text("Words free of a limit")
                    Text("Cut at the start").lineBreak(.headTruncation)
                }
            }
            host.layOut()

            let ends = host.views(AndroidTextView.self).map { view in
                Java.callObject(view.reference, Self.getEllipsize).map { Java.text(Java.callObject($0, Self.name)) }
            }
            XCTAssertEqual(ends, ["END", nil, "START"])
        }
    }

    @MainActor private static let getEllipsize = Java.method(
        JavaAPI.textView, "getEllipsize", "()Landroid/text/TextUtils$TruncateAt;")
    @MainActor private static let name = Java.method(JavaAPI.truncateAt, "name", "()Ljava/lang/String;")

    /// Upper case throughout, and letter spacing in points drawn as Android's share of the text size.
    func testATextsCaseAndLetterSpacingAreItsOwn() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Text("Hello").textCase(.uppercase).fontSize(20).tracking(2)
            }

            let label = try XCTUnwrap(host.views(AndroidTextView.self).first)
            XCTAssertEqual(label.text, "HELLO")
            let size = Java.callFloat(label.reference, JavaAPI.getTextSize)
            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getLetterSpacing), 4 / size, accuracy: 0.0001)
        }
    }

    /// A gradient runs across the whole view, from its first colour at the start point to its last at the end.
    func testABackgroundBrushIsDrawnAcrossTheView() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Text("")
                    .background(Brush.linearGradient(
                        [GradientStop(Color("#FF0000"), 0), GradientStop(Color("#0000FF"), 1)],
                        startPoint: Point(0, 0),
                        endPoint: Point(1, 0)))
                    .width(100)
                    .height(20)
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            host.layOut()

            let label = try XCTUnwrap(host.views(AndroidTextView.self).first)
            let drawn = label.pixels(at: [(0, 20), (199, 20)])
            XCTAssertGreaterThan(drawn[0] >> 16 & 0xFF, 0xF0, String(drawn[0], radix: 16))
            XCTAssertLessThan(drawn[0] & 0xFF, 0x10, String(drawn[0], radix: 16))
            XCTAssertLessThan(drawn[1] >> 16 & 0xFF, 0x10, String(drawn[1], radix: 16))
            XCTAssertGreaterThan(drawn[1] & 0xFF, 0xF0, String(drawn[1], radix: 16))
        }
    }

    /// A label whose colour the tree states not stands in the theme's primary words colour.
    func testALabelsWordsStandInTheThemesPrimaryColour() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Text("Words").horizontalAlignment(.start).verticalAlignment(.start)
            }
            host.layOut()

            let label = try XCTUnwrap(host.views(AndroidTextView.self).first)
            let shown = UInt32(bitPattern: Java.callInt(label.reference, AndroidDriver.getCurrentTextColor))
            let primary = UInt32(bitPattern: Java.callStaticInt(
                AndroidDriver.testText, AndroidDriver.primaryWords, .object(AndroidRenderer.context)))
            XCTAssertEqual(String(shown, radix: 16), String(primary, radix: 16))
        }
    }
}
