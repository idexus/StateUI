// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUIInputViewTests: XCTestCase {
    /// A field takes words as the tree says: read only, unchecked, unpredicted, for an address, centred, its
    /// placeholder coloured, and its caret and selection where they were put.
    func testAFieldTakesWordsAsTheTreeSays() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    TextField("abcdefg")
                        .isReadOnly(true)
                        .isSpellCheckEnabled(false)
                        .isTextPredictionEnabled(false)
                        .inputPurpose(.email)
                        .horizontalTextAlignment(.center)
                        .placeholderColor(Color("#FF0000"))
                        .cursorPosition(2)
                        .selectionLength(3)
                    TextField("")
                }
            }
            let fields = host.views(WinUITextFieldView.self)
            // Read only, spell checked, predicted, the input scope (5, an e-mail address), alignment (0 centre),
            // selection start and length, placeholder coloured, Enter a new line.
            XCTAssertEqual(fields[0].facts, [1, 0, 0, 5, 0, 2, 3, 1, 0])
            XCTAssertEqual(Array(fields[1].facts[0...2]), [0, 1, 1], "WinUI's own where the tree says nothing")
        }
    }

    /// An editor starts a new line on Enter; one growing with its words takes their height, and one that does not
    /// keeps a line's, however many it holds.
    func testAnEditorGrowsWithItsWordsOnlyWhereItIsToldTo() throws {
        try onUIThread {
            let words = State(wrappedValue: "one")
            let host = WinUIRenderer.running {
                VStack {
                    TextEditor(words.projectedValue).growsWithText(true).width(200)
                    TextEditor(words.projectedValue).width(200)
                    Button("More").onClicked { words.wrappedValue = "one\ntwo\nthree\nfour\nfive" }
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let editors = host.views(WinUITextEditorView.self)
            XCTAssertEqual(editors[0].facts[8], 1, "Enter starts a new line")
            let before = editors.map(\.frame.height)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { editors[0].frame.height > before[0] }

            XCTAssertGreaterThan(editors[0].frame.height, before[0] * 2, "grown with its words")
            XCTAssertEqual(editors[1].frame.height, before[1], "a line's height, however many it holds")
        }
    }

    /// The user typing in a search box is heard once; the program's words are shown and heard by nobody.
    func testTheUsersSearchIsHeardAndTheProgramsIsNot() throws {
        try onUIThread {
            let query = State(wrappedValue: "")
            let heard = Received<String>()
            let host = WinUIRenderer.running {
                VStack {
                    SearchField(query.projectedValue).onTextChanged { heard.values.append($0) }
                    Button("Clear").onClicked { query.wrappedValue = "tea" }
                }
            }
            let search = try XCTUnwrap(host.views(WinUISearchFieldView.self).first)

            search.type("coffee")
            host.settle { query.wrappedValue == "coffee" }
            XCTAssertEqual(heard.values, ["coffee"])

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { search.text == "tea" }
            XCTAssertEqual(search.text, "tea")
            XCTAssertEqual(heard.values, ["coffee"], "the program's words heard by nobody")
        }
    }
}

private extension WinUIInputView {
    /// What WinUI holds of the field: `stateui_winui_field_facts`' nine values.
    var facts: [Int32] {
        var facts = [Int32](repeating: 0, count: 9)
        stateui_winui_field_facts(handle, &facts)
        return facts
    }
}
