// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidButtonViewTests: XCTestCase {
    static var allTests: [(String, (AndroidButtonViewTests) -> () throws -> Void)] {
        [
            ("testAButtonIsAsBigAsItsWordsAndItsRoom", testAButtonIsAsBigAsItsWordsAndItsRoom),
        ]
    }

    /// A button is its words and its padding: the least size is the author's, never the platform theme's.
    func testAButtonIsAsBigAsItsWordsAndItsRoom() throws {
        try onMainActor {
            let host = AndroidRenderer.running(reducesMotion: true) {
                VStack {
                    Button("Go").horizontalAlignment(.center)
                    Button("Go").minimumWidth(120).horizontalAlignment(.center)
                }
            }
            host.layOut()
            let buttons = host.views(AndroidButtonView.self)
            let words = try XCTUnwrap(Self.words(of: buttons[0]))
            let room = Self.padding(of: buttons[0])

            XCTAssertEqual(buttons[0].frame.width, words.width + room.width, accuracy: 1)
            XCTAssertEqual(buttons[0].frame.height, words.height + room.height, accuracy: 1)
            XCTAssertEqual(buttons[1].frame.width, 240, "the author's least width, at two pixels a point")
        }
    }

    /// The pixels the button's one line of words takes.
    @MainActor
    private static func words(of button: AndroidButtonView) -> (width: Int32, height: Int32)? {
        guard let layout = Java.callObject(button.reference, TestJava.getLayout) else { return nil }
        defer { Java.release(local: layout) }
        let width = Java.callFloat(layout, TestJava.getLineWidth, .int(0))
        return (Int32(width.rounded(.up)), Java.callInt(layout, TestJava.getLayoutHeight))
    }

    /// The pixels of padding around the button's words, across and down.
    @MainActor
    private static func padding(of button: AndroidButtonView) -> (width: Int32, height: Int32) {
        let reference = button.reference
        return (
            Java.callInt(reference, JavaAPI.getPaddingLeft) + Java.callInt(reference, JavaAPI.getPaddingRight),
            Java.callInt(reference, JavaAPI.getPaddingTop) + Java.callInt(reference, JavaAPI.getPaddingBottom)
        )
    }
}
