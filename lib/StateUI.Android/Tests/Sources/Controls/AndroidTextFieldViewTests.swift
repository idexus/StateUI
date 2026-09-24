// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

/// A greeting over a field, as HelloWorld's page has it.
func greeting(name: State<String>, submitted: Received<Int> = Received(), maximumLength: Int = 40) -> any Page {
    VStack {
        Label(name.wrappedValue.isEmpty ? "Hello!" : "Hello, \(name.wrappedValue)!")
        TextField(name.projectedValue)
            .placeholder("Type your name")
            .maximumLength(maximumLength)
            .onSubmitted { submitted.values.append(1) }
    }
}

final class AndroidTextFieldViewTests: XCTestCase {
    static var allTests: [(String, (AndroidTextFieldViewTests) -> () throws -> Void)] {
        [
            ("testEachKeystrokeReachesTheStateAndStaysTyped", testEachKeystrokeReachesTheStateAndStaysTyped),
            ("testAnEditInTheMiddleKeepsTheUsersCaret", testAnEditInTheMiddleKeepsTheUsersCaret),
            ("testTypingStopsAtTheMaximumLength", testTypingStopsAtTheMaximumLength),
            ("testAStateWriteShowsTheWordsAndIsNotHeardAsTyping", testAStateWriteShowsTheWordsAndIsNotHeardAsTyping),
            ("testAPasswordHidesTheWordsAndKeepsThem", testAPasswordHidesTheWordsAndKeepsThem),
            ("testReturnSubmitsOnce", testReturnSubmitsOnce),
            ("testAReturnKeyIsCaptionedAsTheTreeSays", testAReturnKeyIsCaptionedAsTheTreeSays),
            ("testASearchFieldSubmitsItsSearch", testASearchFieldSubmitsItsSearch),
            ("testAnEditorTakesSeveralLinesAndGrowsOnlyWhenTold", testAnEditorTakesSeveralLinesAndGrowsOnlyWhenTold),
        ]
    }

    func testEachKeystrokeReachesTheStateAndStaysTyped() throws {
        try onMainActor {
            let name = State(wrappedValue: "")
            let host = AndroidRenderer.running { greeting(name: name) }
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)

            for letter in ["A", "d", "a"] {
                field.type(letter)
            }

            XCTAssertEqual(name.wrappedValue, "Ada")
            XCTAssertEqual(field.text, "Ada")
            XCTAssertEqual(field.caret, 3)
            XCTAssertEqual(host.views(AndroidLabelView.self).map(\.text), ["Hello, Ada!"])
        }
    }

    /// The render a keystroke causes carries the same words back: the field is not written, and the caret stays.
    func testAnEditInTheMiddleKeepsTheUsersCaret() throws {
        try onMainActor {
            let name = State(wrappedValue: "")
            let host = AndroidRenderer.running { greeting(name: name) }
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)
            field.type("Aa")

            field.select(from: 1, length: 0)
            field.type("d")

            XCTAssertEqual(name.wrappedValue, "Ada")
            XCTAssertEqual(field.caret, 2)
        }
    }

    func testTypingStopsAtTheMaximumLength() throws {
        try onMainActor {
            let name = State(wrappedValue: "")
            let host = AndroidRenderer.running { greeting(name: name, maximumLength: 3) }
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)

            field.type("Ada")
            field.type("m")

            XCTAssertEqual(name.wrappedValue, "Ada")
            XCTAssertEqual(field.text, "Ada")
        }
    }

    func testAStateWriteShowsTheWordsAndIsNotHeardAsTyping() throws {
        try onMainActor {
            let name = State(wrappedValue: "")
            let typed = Received<String>()
            let host = AndroidRenderer.running {
                VStack {
                    TextField(name.projectedValue).onTextChanged { typed.values.append($0) }
                    Button("Ada").onClicked { name.wrappedValue = "Ada" }
                }
            }
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()

            XCTAssertEqual(field.text, "Ada")
            XCTAssertEqual(field.caret, 3)
            XCTAssertEqual(typed.values, [])
        }
    }

    func testAPasswordHidesTheWordsAndKeepsThem() throws {
        try onMainActor {
            let name = State(wrappedValue: "")
            let hidden = State(wrappedValue: false)
            let host = AndroidRenderer.running {
                VStack {
                    TextField(name.projectedValue).isPassword(hidden.wrappedValue).fontAttributes(.bold)
                    Button("Hide").onClicked { hidden.wrappedValue = true }
                }
            }
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)
            field.type("secret")

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()

            XCTAssertTrue(field.isPassword)
            XCTAssertEqual(field.text, "secret")
            XCTAssertEqual(field.fontAttributes, .bold)
            XCTAssertEqual(name.wrappedValue, "secret")
        }
    }

    /// The keyboard's action, and a hardware Return pressed and let go, each submit once.
    func testReturnSubmitsOnce() throws {
        try onMainActor {
            let name = State(wrappedValue: "")
            let submitted = Received<Int>()
            let host = AndroidRenderer.running { greeting(name: name, submitted: submitted) }
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)

            // EditorInfo.IME_ACTION_DONE, and KeyEvent.KEYCODE_ENTER.
            Java.call(field.reference, TestJava.onEditorAction, .int(6))
            field.press(key: 66)

            XCTAssertEqual(submitted.values.count, 2)
        }
    }

    /// A field's return key is the platform's where nothing is said, and the tree's choice where it is; a
    /// search field's is a search.
    func testAReturnKeyIsCaptionedAsTheTreeSays() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    TextField("")
                    TextField("").returnKey(.next)
                    SearchField("")
                }
            }
            let fields = host.views(AndroidTextFieldView.self)

            // EditorInfo.IME_ACTION_UNSPECIFIED, IME_ACTION_NEXT and IME_ACTION_SEARCH.
            XCTAssertEqual(fields.map { Java.callInt($0.reference, TestJava.getImeOptions) }, [0, 5, 3])
        }
    }

    func testASearchFieldSubmitsItsSearch() throws {
        try onMainActor {
            let query = State(wrappedValue: "")
            let searched = Received<String>()
            let host = AndroidRenderer.running {
                SearchField(query.projectedValue).onSubmitted { searched.values.append(query.wrappedValue) }
            }
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)

            field.type("ada")
            Java.call(field.reference, TestJava.onEditorAction, .int(3))

            XCTAssertEqual(query.wrappedValue, "ada")
            XCTAssertEqual(searched.values, ["ada"])
        }
    }

    /// An editor takes several lines; it grows with them only where the tree says so, and one that does not is
    /// as tall as its room.
    func testAnEditorTakesSeveralLinesAndGrowsOnlyWhenTold() {
        onMainActor {
            let draft = State(wrappedValue: "one\ntwo\nthree")
            let host = AndroidRenderer.running {
                VStack {
                    TextEditor(draft.projectedValue).horizontalAlignment(.start)
                    TextEditor(draft.projectedValue).growsWithText(true).horizontalAlignment(.start)
                    TextEditor(draft.projectedValue).height(100).horizontalAlignment(.start)
                }
            }
            host.layOut()
            let editors = host.views(AndroidTextFieldView.self)

            XCTAssertEqual(editors[0].text, "one\ntwo\nthree")
            XCTAssertGreaterThan(editors[1].frame.height, editors[0].frame.height * 3 / 2, "three lines against one")
            XCTAssertEqual(editors[2].frame.height, 200, "its room, at two pixels a point")
            let multiLine = Java.callInt(editors[0].reference, TestJava.getInputType) & 0x20000
            XCTAssertEqual(multiLine, 0x20000)
        }
    }
}
