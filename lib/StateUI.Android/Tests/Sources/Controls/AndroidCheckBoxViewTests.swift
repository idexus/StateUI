// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidCheckBoxViewTests: XCTestCase {
    static var allTests: [(String, (AndroidCheckBoxViewTests) -> () throws -> Void)] {
        [
            ("testACheckBoxShowsWhatTheTreeSays", testACheckBoxShowsWhatTheTreeSays),
            ("testAUsersTickReachesTheStateAndTheHandlerOnce", testAUsersTickReachesTheStateAndTheHandlerOnce),
            ("testATintColoursTheBoxAndNilPutsThePlatformsBack", testATintColoursTheBoxAndNilPutsThePlatformsBack),
        ]
    }

    /// The tree ticks the box, and the program's tick is not heard as the user's.
    func testACheckBoxShowsWhatTheTreeSays() throws {
        try onMainActor {
            let on = State(wrappedValue: false)
            let heard = Received<Bool>()
            let host = AndroidRenderer.running {
                VStack {
                    CheckBox(on.projectedValue).onToggled { heard.values.append($0) }
                    Button("On").onClicked { on.wrappedValue = true }
                }
            }
            let box = try XCTUnwrap(host.views(AndroidCheckBoxView.self).first)
            XCTAssertFalse(box.isOn)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()

            XCTAssertTrue(box.isOn, "the state the button wrote reached the box")
            XCTAssertEqual(heard.values, [], "and nobody heard it as the user's")
        }
    }

    func testAUsersTickReachesTheStateAndTheHandlerOnce() throws {
        try onMainActor {
            let on = State(wrappedValue: false)
            let heard = Received<Bool>()
            let host = AndroidRenderer.running {
                VStack {
                    Label(on.wrappedValue ? "on" : "off")
                    CheckBox(on.projectedValue).onToggled { heard.values.append($0) }
                }
            }
            let box = try XCTUnwrap(host.views(AndroidCheckBoxView.self).first)

            box.click()

            XCTAssertTrue(on.wrappedValue)
            XCTAssertEqual(heard.values, [true])
            XCTAssertEqual(host.views(AndroidLabelView.self).map(\.text), ["on"])
            XCTAssertTrue(box.isOn)
        }
    }

    func testATintColoursTheBoxAndNilPutsThePlatformsBack() throws {
        try onMainActor {
            let host = AndroidRenderer.running { CheckBox(true).tint(.firebrick) }
            let box = try XCTUnwrap(host.views(AndroidCheckBoxView.self).first)
            let firebrick = Int32(bitPattern: 0xFFB2_2222)

            XCTAssertEqual(Self.defaultColor(of: box), firebrick)

            box.setTint(nil)

            XCTAssertNotEqual(Self.defaultColor(of: box), firebrick)
        }
    }

    @MainActor
    private static func defaultColor(of box: AndroidCheckBoxView) -> Int32? {
        guard let list = Java.callObject(box.reference, JavaAPI.getButtonTintList) else { return nil }
        defer { Java.release(local: list) }
        return Java.callInt(list, TestJava.getDefaultColor)
    }
}
