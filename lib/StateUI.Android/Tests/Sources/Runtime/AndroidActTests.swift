// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidActTests: XCTestCase {
    static var allTests: [(String, (AndroidActTests) -> () throws -> Void)] {
        [
            ("testTheClockAndTheZoneAnswerFromThePlatform", testTheClockAndTheZoneAnswerFromThePlatform),
            ("testFocusPutsTheKeyboardOnTheAimedField", testFocusPutsTheKeyboardOnTheAimedField),
        ]
    }

    /// `ClockTime.now()` and `TimeZoneInfo.local()` are acts the host answers from the platform's clock and zone.
    func testTheClockAndTheZoneAnswerFromThePlatform() throws {
        try onMainActor {
            let said = State(wrappedValue: "")
            let host = AndroidRenderer.running {
                Label(said.wrappedValue).onCreated {
                    let time = try await ClockTime.now()
                    let zone = try await TimeZoneInfo.local()
                    said.wrappedValue = "\(time.hour) \(time.minute) \(zone)"
                }
            }
            host.settle { !said.wrappedValue.isEmpty }

            let parts = said.wrappedValue.split(separator: " ")
            XCTAssertEqual(parts.count, 3, said.wrappedValue)
            XCTAssertTrue((0..<24).contains(Int(parts.first ?? "") ?? -1), said.wrappedValue)
            XCTAssertFalse(parts.last?.isEmpty ?? true)
        }
    }

    func testFocusPutsTheKeyboardOnTheAimedField() throws {
        try onMainActor {
            let answers = Received<Bool>()
            let host = AndroidRenderer.running { FocusPage(answers: answers) }
            host.layOut()
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            host.settle { !answers.values.isEmpty }

            XCTAssertEqual(answers.values, [true])
            XCTAssertTrue(Java.callBool(field.reference, TestJava.hasFocus))
        }
    }
}

/// A field, and a button that aims the focus at it.
private struct FocusPage: ContentView {
    @Aim(TextField.self) private var field
    let answers: Received<Bool>

    var content: any View {
        let answers = self.answers
        let field = self.field
        return VStack {
            TextField("").aim(field)
            Button("Focus").onClicked { answers.values.append(try await field.focus()) }
        }
    }
}
