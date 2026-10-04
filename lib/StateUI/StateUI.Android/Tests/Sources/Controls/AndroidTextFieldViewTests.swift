// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import XCTest

/// A greeting over a field, as HelloWorld's page has it.
func greeting(name: State<String>, submitted: Received<Int> = Received(), maximumLength: Int = 40) -> some View {
    VStack {
        Text(name.wrappedValue.isEmpty ? "Hello!" : "Hello, \(name.wrappedValue)!")
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
            ("testAReturnsReleaseStaysOnTheFieldItsSubmitAimedAt", testAReturnsReleaseStaysOnTheFieldItsSubmitAimedAt),
            ("testAHardwareReturnStartsANewLineInAnEditor", testAHardwareReturnStartsANewLineInAnEditor),
            ("testAReturnKeyIsCaptionedAsTheTreeSays", testAReturnKeyIsCaptionedAsTheTreeSays),
            ("testASearchFieldSubmitsItsSearch", testASearchFieldSubmitsItsSearch),
            ("testAnEditorTakesSeveralLinesAndGrowsOnlyWhenTold", testAnEditorTakesSeveralLinesAndGrowsOnlyWhenTold),
            ("testWordsStandAcrossAsTheTreeSaysAndDownAsTheKindDoes", testWordsStandAcrossAsTheTreeSaysAndDownAsTheKindDoes),
            ("testAPurposeGivesTheKeyboardItsKeysAndItsCapitals", testAPurposeGivesTheKeyboardItsKeysAndItsCapitals),
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
            XCTAssertEqual(host.views(AndroidTextView.self).map(\.text), ["Hello, Ada!"])
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

    /// A Return is one keystroke: its release does not reach, as a Return of its own, the field its submit put the
    /// focus on - out of touch mode Android takes a Return released on a line for a move to the view below it, and
    /// a scanner's Enter would press the button there.
    func testAReturnsReleaseStaysOnTheFieldItsSubmitAimedAt() throws {
        try onMainActor {
            let path = State(wrappedValue: [Int]())
            let driver = AndroidDriver()
            _ = driver.start(clock: nil, reducesMotion: false) {
                NavigationStack(path.projectedValue) {
                    TextField(State(wrappedValue: "").projectedValue).onSubmitted { path.wrappedValue = [1] }
                } destination: { _ in
                    AimedFieldPage()
                }
            }
            defer {
                driver.finish()
                TestWindow.touchMode(true)
            }
            let renderer = try XCTUnwrap(driver.renderer)
            let typed = try XCTUnwrap(renderer.views(AndroidTextFieldView.self).first)
            XCTAssertTrue(Java.callBool(typed.reference, TestJava.requestFocus))
            TestWindow.touchMode(false)

            TestWindow.press(key: 66) {
                for _ in 0..<10 {
                    driver.step()
                }
            }
            for _ in 0..<10 {
                driver.step()
            }

            XCTAssertEqual(path.wrappedValue, [1])
            let field = try XCTUnwrap(renderer.views(AndroidTextFieldView.self).last)
            let below = try XCTUnwrap(renderer.views(AndroidButtonView.self).first)
            XCTAssertTrue(
                Java.callBool(field.reference, TestJava.hasFocus), "the field the page aimed at, not \(TestWindow.focused)")
            XCTAssertFalse(Java.callBool(below.reference, TestJava.hasFocus), "the button below it")
        }
    }

    /// A hardware Return in an editor starts a new line, as the keyboard's does.
    func testAHardwareReturnStartsANewLineInAnEditor() throws {
        try onMainActor {
            let draft = State(wrappedValue: "")
            let host = AndroidRenderer.running { TextEditor(draft.projectedValue) }
            let editor = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)

            editor.type("one")
            editor.press(key: 66)
            editor.type("two")

            XCTAssertEqual(draft.wrappedValue, "one\ntwo")
        }
    }

    /// A field's return key is the platform's where nothing is said, and the tree's choice where it is; a
    /// search field's is a search.
    func testAReturnKeyIsCaptionedAsTheTreeSays() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    TextField("")
                    TextField("").submitLabel(.next)
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

    /// A field's words and its placeholder stand across it where `horizontalTextAlignment` says, and down where
    /// its kind stands them: a line's in its middle, an editor's at its top.
    func testWordsStandAcrossAsTheTreeSaysAndDownAsTheKindDoes() {
        onMainActor {
            let words = State(wrappedValue: "")
            let host = AndroidRenderer.running {
                VStack {
                    TextField(words.projectedValue).horizontalTextAlignment(.center)
                    SearchField(words.projectedValue).horizontalTextAlignment(.end)
                    TextEditor(words.projectedValue).horizontalTextAlignment(.center)
                }
            }
            let gravity = host.views(AndroidTextFieldView.self).map { Java.callInt($0.reference, JavaAPI.getGravity) }

            XCTAssertEqual(gravity, [
                ViewConstants.gravity(across: .center) | ViewConstants.gravity(down: .center),
                ViewConstants.gravity(across: .end) | ViewConstants.gravity(down: .center),
                ViewConstants.gravity(across: .center) | ViewConstants.gravity(down: .start),
            ])
        }
    }

    /// A purpose picks the keys a keyboard offers and where capitals go: plain words are taken as typed, with no
    /// suggestions; an address takes its keys; text starts its sentences in capitals; a password stays hidden and
    /// corrected by nothing.
    func testAPurposeGivesTheKeyboardItsKeysAndItsCapitals() {
        onMainActor {
            let words = State(wrappedValue: "")
            let host = AndroidRenderer.running {
                VStack {
                    TextField(words.projectedValue).inputPurpose(.plain)
                    TextField(words.projectedValue).inputPurpose(.email)
                    TextField(words.projectedValue).inputPurpose(.text)
                    TextField(words.projectedValue).inputPurpose(.numeric)
                    TextField(words.projectedValue).inputPurpose(.email).isPassword(true)
                }
            }
            let types = host.views(AndroidTextFieldView.self).map { Java.callInt($0.reference, TestJava.getInputType) }

            // InputType: TEXT 0x1, NUMBER 0x2; EMAIL 0x20, PASSWORD 0x80; CAP_SENTENCES 0x4000, AUTO_CORRECT 0x8000,
            // NO_SUGGESTIONS 0x80000; a number's DECIMAL 0x2000.
            XCTAssertEqual(types.map { String($0, radix: 16) }, ["80001", "8021", "c001", "2002", "81"])
        }
    }
}

/// A page whose field takes the focus each time the page appears, over a button.
private struct AimedFieldPage: View {
    @Aim(TextField.self) private var field

    var body: some View {
        let field = self.field
        return VStack {
            TextField(State(wrappedValue: "").projectedValue).aim(field)
            Button("Below")
        }
        .onAppearing { try await field.focus() }
    }
}
