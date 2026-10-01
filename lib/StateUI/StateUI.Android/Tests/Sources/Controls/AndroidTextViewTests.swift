// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidTextViewTests: XCTestCase {
    static var allTests: [(String, (AndroidTextViewTests) -> () throws -> Void)] {
        [
            ("testTextOutsideTheBasicPlaneComesBackWhole", testTextOutsideTheBasicPlaneComesBackWhole),
            ("testAClearedSizePutsBackThePlatformsOwn", testAClearedSizePutsBackThePlatformsOwn),
            ("testPaddingIsTheRoomAroundTheWordsWhateverTheBackground", testPaddingIsTheRoomAroundTheWordsWhateverTheBackground),
        ]
    }

    override func setUp() {
        onMainActor { _ = AndroidRenderer.running { VStack {} } }
    }

    /// Words cross as UTF-16: modified UTF-8 cannot hold a character outside the basic plane.
    func testTextOutsideTheBasicPlaneComesBackWhole() {
        onMainActor {
            let label = AndroidLabelView()

            label.setText("🙂 zażółć")

            XCTAssertEqual(label.text, "🙂 zażółć")
        }
    }

    func testAClearedSizePutsBackThePlatformsOwn() {
        onMainActor {
            let label = AndroidLabelView()
            let platforms = Java.callFloat(label.reference, TestJava.getTextSize)

            label.setFontSize(40)
            XCTAssertNotEqual(Java.callFloat(label.reference, TestJava.getTextSize), platforms)
            label.setFontSize(nil)

            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getTextSize), platforms)
        }
    }

    /// A colour behind a button takes the padding its own background brought; the tree's padding stays.
    func testPaddingIsTheRoomAroundTheWordsWhateverTheBackground() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Button("Styled").background(Color("#512BD4")).padding(16, 11)
                }
            }
            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)

            XCTAssertEqual(Java.callInt(button.reference, JavaAPI.getPaddingLeft), 32, "sixteen points at two pixels a point")
            XCTAssertEqual(Java.callInt(button.reference, JavaAPI.getPaddingTop), 22)
            XCTAssertEqual(Java.callInt(button.reference, JavaAPI.getPaddingRight), 32)
        }
    }
}
