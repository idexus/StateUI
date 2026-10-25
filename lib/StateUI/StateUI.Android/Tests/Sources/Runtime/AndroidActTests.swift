// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import XCTest

final class AndroidActTests: XCTestCase {
    static var allTests: [(String, (AndroidActTests) -> () throws -> Void)] {
        [
            ("testTheClockAndTheZoneAnswerFromThePlatform", testTheClockAndTheZoneAnswerFromThePlatform),
            ("testFocusPutsTheKeyboardOnTheAimedField", testFocusPutsTheKeyboardOnTheAimedField),
            ("testAPromptsKeyboardIsAFieldsOfItsPurpose", testAPromptsKeyboardIsAFieldsOfItsPurpose),
            ("testAPromptHoldsItsBoundInCharacters", testAPromptHoldsItsBoundInCharacters),
        ]
    }

    /// `ClockTime.now()` and `TimeZoneInfo.local()` are acts the host answers from the platform's clock and zone.
    func testTheClockAndTheZoneAnswerFromThePlatform() {
        onMainActor {
            let said = State(wrappedValue: "")
            let host = AndroidRenderer.running {
                Text(said.wrappedValue).onCreated {
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

    /// A prompt's field offers the keyboard a text field of its purpose offers: a number its decimal point.
    func testAPromptsKeyboardIsAFieldsOfItsPurpose() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    TextField(State(wrappedValue: "").projectedValue).inputPurpose(.numeric)
                    Button("Ask").onClicked(.ignoreWhileRunning) {
                        _ = try await WindowSession().prompt("How many?", accept: "OK", cancel: "No", inputPurpose: .numeric)
                    }
                }
            }
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)
            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            let fieldType = { Java.callStaticInt(AndroidDriver.dialogs, Self.fieldInputType) }
            host.settle { fieldType() != -1 }

            XCTAssertEqual(fieldType(), Java.callInt(field.reference, Self.getInputType))
            XCTAssertTrue(Java.frame {
                Java.callStaticBool(
                    AndroidDriver.dialogs, AndroidDriver.answer, .int(AndroidAnswer.cancel.rawValue), .int(-1),
                    .object(nil))
            })
            host.settle {
                TestWindow.run(for: 10)
                return fieldType() == -1
            }
        }
    }

    /// A prompt's field holds its bound in characters, as every field does: an emoji with its skin tone is one.
    func testAPromptHoldsItsBoundInCharacters() throws {
        try onMainActor {
            let answers = Received<String>()
            let host = AndroidRenderer.running {
                Button("Ask").onClicked(.ignoreWhileRunning) {
                    answers.values.append(
                        try await WindowSession().prompt("Name", accept: "OK", cancel: "No", maximumLength: 3) ?? "nothing")
                }
            }
            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            host.settle { Java.callStaticInt(AndroidDriver.dialogs, Self.fieldInputType) != -1 }

            XCTAssertTrue(Java.frame {
                Java.callStaticBool(
                    AndroidDriver.dialogs, AndroidDriver.answer, .int(AndroidAnswer.accept.rawValue), .int(-1),
                    .object(Java.string("a👍🏽bc")))
            })
            host.settle {
                TestWindow.run(for: 10)
                return !answers.values.isEmpty
            }
            XCTAssertEqual(answers.values, ["a👍🏽b"])
        }
    }

    @MainActor private static let fieldInputType = Java.staticMethod(AndroidDriver.dialogs, "fieldInputType", "()I")
    @MainActor private static let getInputType = Java.method(JavaAPI.textView, "getInputType", "()I")

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
private struct FocusPage: View {
    @Aim(TextField.self) private var field
    let answers: Received<Bool>

    var body: some View {
        let answers = self.answers
        let field = self.field
        return VStack {
            TextField("").aim(field)
            Button("Focus").onClicked(.ignoreWhileRunning) { answers.values.append(try await field.focus()) }
        }
    }
}
