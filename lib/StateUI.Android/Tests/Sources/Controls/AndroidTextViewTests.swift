// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidTextViewTests: XCTestCase {
    static var allTests: [(String, (AndroidTextViewTests) -> () throws -> Void)] {
        [
            ("testTextOutsideTheBasicPlaneComesBackWhole", testTextOutsideTheBasicPlaneComesBackWhole),
            ("testAClearedSizePutsBackThePlatformsOwn", testAClearedSizePutsBackThePlatformsOwn),
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
}
