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
            ("testALabelsWordsStandInTheThemesPrimaryColor", testALabelsWordsStandInTheThemesPrimaryColor),
            ("testAPaddingsStartStandsWhereTheDirectionStarts", testAPaddingsStartStandsWhereTheDirectionStarts),
        ]
    }

    /// A padding's start and end follow the direction: a text's and a button's start stand at the left left to right
    /// and at the right right to left - again as the direction turns.
    func testAPaddingsStartStandsWhereTheDirectionStarts() throws {
        try onMainActor {
            let rightToLeft = State(wrappedValue: false)
            let host = AndroidRenderer.running {
                VStack {
                    Text("Ada").padding(start: 16, top: 0, end: 2, bottom: 0)
                    Button("Go").padding(start: 16, top: 0, end: 2, bottom: 0)
                }
                .layoutDirection(rightToLeft.wrappedValue ? .rightToLeft : .leftToRight)
            }
            let views: [AndroidTextualView] = [
                try XCTUnwrap(host.views(AndroidTextView.self).first),
                try XCTUnwrap(host.views(AndroidButtonView.self).first),
            ]
            let (start, end) = (views[0].pixels(16), views[0].pixels(2))
            @MainActor func sides(_ view: AndroidTextualView) -> [Int32] {
                [JavaAPI.getPaddingLeft, JavaAPI.getPaddingRight].map { Java.callInt(view.reference, $0) }
            }
            XCTAssertEqual(views.map(sides), [[start, end], [start, end]], "the start at the left")

            rightToLeft.wrappedValue = true
            host.runtime.pump.turn()
            XCTAssertEqual(views.map(sides), [[end, start], [end, start]], "the start at the right")
        }
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

    /// A gradient runs across the whole view, from its first color at the start point to its last at the end.
    func testABackgroundBrushIsDrawnAcrossTheView() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Text("")
                    .background(Brush.linearGradient(
                        [GradientStop(Color(hex: 0xFF0000), 0), GradientStop(Color(hex: 0x0000FF), 1)],
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

    /// A label whose color the tree states not stands in the theme's primary words color.
    func testALabelsWordsStandInTheThemesPrimaryColor() throws {
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
