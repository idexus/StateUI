// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUITextFieldViewTests: XCTestCase {
    /// A field turned into a password stands as WinUI's `PasswordBox` in the field's place, holding the words typed,
    /// its placeholder, its name to automation, its focus and its taps heard; turned back, a `TextBox` again, with
    /// no handler left hanging on the box let go.
    func testAPasswordFieldIsAPasswordBoxInTheFieldsPlace() throws {
        try onUIThread {
            let hidden = State(wrappedValue: false)
            let words = State(wrappedValue: "")
            let focused = State(wrappedValue: false)
            let host = WinUIRenderer.running {
                VStack {
                    TextField(words.projectedValue)
                        .isPassword(hidden.wrappedValue)
                        .placeholder("Password")
                        .isFocused(focused.projectedValue)
                        .accessibilityIdentifier("secret")
                        .onTapped {}
                        .width(200)
                }
            }
            host.layOut()
            let field = try XCTUnwrap(host.views(WinUITextFieldView.self).first)
            field.type("hunter2")
            host.settle { words.wrappedValue == "hunter2" }
            let hung = stateui_winui_hung_handlers()
            let listening = stateui_winui_listeners()

            hidden.wrappedValue = true
            host.settle { Self.read(field, "password") == "1" }
            XCTAssertEqual(Self.read(field, "password"), "1", "a PasswordBox")
            XCTAssertEqual(field.text, "hunter2", "the words typed kept")
            XCTAssertEqual(Self.read(field, "placeholder"), "Password")
            XCTAssertEqual(field.automationWords.identifier, "secret")
            host.layOut()
            XCTAssertTrue(field.reaches(100, field.frame.height / 2), "standing in the field's place")

            field.type("hunter3")
            host.settle { words.wrappedValue == "hunter3" }
            XCTAssertEqual(words.wrappedValue, "hunter3", "the password's typing heard")
            XCTAssertTrue(stateui_winui_focus(field.handle, true))
            host.settle { focused.wrappedValue }
            XCTAssertTrue(focused.wrappedValue, "its focus heard")

            hidden.wrappedValue = false
            host.settle { Self.read(field, "password") == "0" }
            XCTAssertEqual(Self.read(field, "password"), "0", "a TextBox again")
            XCTAssertEqual(field.text, "hunter3")
            host.settle { stateui_winui_hung_handlers() == hung }
            XCTAssertEqual(stateui_winui_hung_handlers(), hung, "no handler left on a box let go")
            XCTAssertEqual(stateui_winui_listeners(), listening, "one listener, the field's")
        }
    }

    /// A field takes the traits its purpose gives on every host (`InputTraits`): plain words are neither spell
    /// checked nor predicted, though the tree leaves both on; prose starts its sentences in capitals and a chat
    /// offers emoji, each by its input scope.
    func testAFieldTakesTheTraitsItsPurposeGives() throws {
        try onUIThread {
            let words = State(wrappedValue: "")
            let purpose = State(wrappedValue: InputPurpose.plain)
            let host = WinUIRenderer.running {
                VStack {
                    TextField(words.projectedValue)
                        .inputPurpose(purpose.wrappedValue)
                        .width(200)
                }
            }
            host.layOut()
            let field = try XCTUnwrap(host.views(WinUITextFieldView.self).first)
            XCTAssertEqual(Self.checkedAndPredicted(field), [0, 0], "plain words")

            let scopes: [(InputPurpose, WinUIInputScope)] = [
                (.text, .text), (.chat, .chat), (.email, .email), (.numeric, .number), (.default, .default),
            ]
            for (written, scope) in scopes {
                purpose.wrappedValue = written
                host.settle { Self.read(field, "scope") == "\(scope.rawValue)" }
                XCTAssertEqual(Self.read(field, "scope"), "\(scope.rawValue)", "\(written)")
            }
            XCTAssertEqual(Self.checkedAndPredicted(field), [1, 1], "the default's words")
        }
    }

    /// Whether `field`'s words are spell checked and predicted, 1 or 0 each.
    @MainActor private static func checkedAndPredicted(_ field: WinUIView) -> [Int32] {
        var facts = [Int32](repeating: 0, count: 9)
        stateui_winui_field_facts(field.handle, &facts)
        return Array(facts[1...2])
    }

    @MainActor private static func read(_ view: WinUIView, _ what: String) -> String {
        WinUIStrings.read { stateui_winui_read(view.handle, what, $0, $1) }
    }
}
