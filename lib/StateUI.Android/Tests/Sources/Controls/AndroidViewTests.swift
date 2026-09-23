// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidViewTests: XCTestCase {
    static var allTests: [(String, (AndroidViewTests) -> () throws -> Void)] {
        [
            ("testAClearedBackgroundPutsBackTheOneTheViewWasMadeWith", testAClearedBackgroundPutsBackTheOneTheViewWasMadeWith),
        ]
    }

    override func setUp() {
        onMainActor { _ = AndroidRenderer.running { VStack {} } }
    }

    /// A button, a field, a switch draw their own background; a colour taken away gives it back.
    func testAClearedBackgroundPutsBackTheOneTheViewWasMadeWith() {
        onMainActor {
            let field = AndroidTextFieldView()
            let made = Java.callObject(field.reference, JavaAPI.getBackground)

            field.setBackground(.color(red: 200, green: 0, blue: 0, alpha: 255))
            field.setBackground(nil)

            let now = Java.callObject(field.reference, JavaAPI.getBackground)
            XCTAssertNotNil(made)
            XCTAssertTrue(Java.jni.IsSameObject(Java.env, made, now) != 0, "the field's own background came back")
            Java.release(local: now)
            Java.release(local: made)
        }
    }
}
