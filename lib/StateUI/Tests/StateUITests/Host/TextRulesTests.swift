// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// Words as every host reads them: an element's words and their look, the lines a break allows, the space between
/// letters, words typed past their bound, a selection in a toolkit's units, and a picker's choice.
final class TextRulesTests: XCTestCase {
    /// The words are given in their case where the words or the case changed, and the look where the font or the
    /// colour did; nothing where nothing of them changed.
    func testAnElementsWordsAndLookAreReadWhereTheyChanged() throws {
        let held: [Prop: HostValue] = [
            .text: .string("Save"), .textCase: TextCase.uppercase.propValue, .fontSize: .number(17),
            .textColor: Color(red: 255, green: 0, blue: 0).propValue,
        ]
        let changed = ElementValues<LabelContract>(changed: [.text, .fontSize], reading: { held[$0] })
        XCTAssertEqual(TextMembers.words(changed), "SAVE")
        let look = try XCTUnwrap(TextMembers.look(changed))
        XCTAssertEqual(look.size, 17)
        XCTAssertEqual(look.color, Color(red: 255, green: 0, blue: 0).propValue)

        let still = ElementValues<LabelContract>(changed: [.padding], reading: { held[$0] })
        XCTAssertNil(TextMembers.words(still))
        XCTAssertNil(TextMembers.look(still))
    }

    /// A break that does not wrap keeps one line; wrapped words stand on the lines allowed, none where none are.
    func testABreakAllowsItsLines() {
        XCTAssertEqual(LineBreak.tailTruncation.lines(maximum: 3), 1)
        XCTAssertEqual(LineBreak.noWrap.lines(maximum: nil), 1)
        XCTAssertEqual(LineBreak.wordWrap.lines(maximum: 3), 3)
        XCTAssertNil(LineBreak.characterWrap.lines(maximum: 0))
        XCTAssertNil(LineBreak.wordWrap.lines(maximum: nil))
        XCTAssertTrue(LineBreak.middleTruncation.truncates)
        XCTAssertFalse(LineBreak.wordWrap.truncates)
    }

    /// The space between letters is a share of the font's size; nothing for a size that is none.
    func testLetterSpacingIsAShareOfTheFontsSize() {
        var look = TextLook()
        look.letterSpacing = 2
        XCTAssertEqual(look.letterSpacing(inEmsOf: 16), 0.125)
        XCTAssertEqual(look.letterSpacing(inEmsOf: 0), 0)
    }

    /// Words past their bound are cut to the characters that fit - an emoji one character - and words within it,
    /// or with no bound, are left.
    func testTypedWordsAreCutToTheirBound() {
        XCTAssertEqual(InputWords.cut("Adam", toBound: 3), "Ada")
        XCTAssertEqual(InputWords.cut("a👍🏽b", toBound: 2), "a👍🏽")
        XCTAssertNil(InputWords.cut("Ada", toBound: 3))
        XCTAssertNil(InputWords.cut("Ada", toBound: nil))
    }

    /// A selection in characters reaches a toolkit in the UTF-16 units those characters take, its ends kept within
    /// the words.
    func testASelectionIsCountedInUTF16Units() {
        let words = "👍🏽ab"
        XCTAssertTrue(InputWords.utf16Selection(start: 1, length: 1, in: words) == (4, 1))
        XCTAssertTrue(InputWords.utf16Selection(start: 0, length: 9, in: words) == (0, 6))
        XCTAssertTrue(InputWords.utf16Selection(start: -2, length: 0, in: words) == (0, 0))
    }

    /// A picker is given its choices where they changed, and its choice only where the tree changed it or the
    /// choices - a place no choice stands at is none.
    func testAPickersChoiceIsWrittenOnlyWhereTheTreeChangedIt() {
        var picker = PickerChoices()
        let first = picker.write(["S", "M"], chosen: 1, choiceChanged: false)
        XCTAssertEqual(first.choices, ["S", "M"])
        XCTAssertTrue(first.writesChoice, "new choices bring their choice")
        XCTAssertEqual(first.chosen, 1)

        let again = picker.write(["S", "M"], chosen: 0, choiceChanged: false)
        XCTAssertNil(again.choices)
        XCTAssertFalse(again.writesChoice, "the user's choice is not argued with")

        let program = picker.write(["S", "M"], chosen: 5, choiceChanged: true)
        XCTAssertTrue(program.writesChoice)
        XCTAssertNil(program.chosen, "a place no choice stands at is none")
    }
}
