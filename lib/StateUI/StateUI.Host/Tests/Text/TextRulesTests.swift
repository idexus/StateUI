// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Words as every host reads them: an element's words and their look, the lines a break allows, the space between
/// letters, words typed past their bound, a selection in a toolkit's units, and a picker's choice.
@MainActor
final class TextRulesTests: XCTestCase {
    /// The words are given in their case where the words or the case changed, and the look where the font or the
    /// colour did; nothing where nothing of them changed - though the whole look is there to read.
    func testAnElementsWordsAndLookAreReadWhereTheyChanged() throws {
        let held: [Prop: HostValue] = [
            .text: .string("Save"), .textCase: TextCase.uppercase.propValue, .fontSize: .number(17),
            .textColor: Color(red: 255, green: 0, blue: 0).propValue,
        ]
        let changed = ElementValues<TextContract>(changed: [.text, .fontSize], reading: { held[$0] })
        XCTAssertEqual(TextMembers.words(changed), "SAVE")
        let look = try XCTUnwrap(TextMembers.look(changed))
        XCTAssertEqual(look.size, 17)
        XCTAssertEqual(look.color, Color(red: 255, green: 0, blue: 0).propValue)

        let still = ElementValues<TextContract>(changed: [.padding], reading: { held[$0] })
        XCTAssertNil(TextMembers.words(still))
        XCTAssertNil(TextMembers.look(still))
        XCTAssertEqual(TextMembers.look(of: still), look, "the whole look, changed or not")

        let fixed = ElementValues<TextContract>(changed: [.isFontAutoScalingEnabled]) {
            $0 == .isFontAutoScalingEnabled ? .bool(false) : held[$0]
        }
        XCTAssertEqual(TextMembers.look(fixed)?.scales, false, "the look where only its scaling changed")
    }

    /// A slant the tree gives - upright included - is the tree's: a toolkit whose theme draws words italic draws
    /// them upright then; given nothing, the theme's own stands.
    func testASlantTheTreeGivesIsTheTrees() {
        let none = ElementValues<ButtonContract>(changed: [.fontAttributes]) {
            $0 == .fontAttributes ? FontAttributes.none.propValue : nil
        }
        XCTAssertTrue(TextMembers.look(of: none).attributesGiven, "upright given")
        XCTAssertFalse(TextMembers.look(of: ElementValues<ButtonContract>(changed: []) { _ in nil }).attributesGiven)

        var run = TextLook()
        run.attributesGiven = true
        var label = TextLook()
        label.attributes = .italic
        XCTAssertEqual(run.over(label).attributes, .none, "a run given upright stands upright in an italic label")
        XCTAssertEqual(TextLook().over(label).attributes, .italic, "a run given nothing takes its label's")
    }

    /// A style and a weight are read from the tree, changed or not, and a run takes its label's where it says none.
    func testAStyleAndAWeightAreTheTreesOrTheLabels() throws {
        let held: [Prop: HostValue] = [.textStyle: TextStyle.title.propValue, .fontWeight: FontWeight.semibold.propValue]
        let look = try XCTUnwrap(TextMembers.look(ElementValues<TextContract>(changed: [.textStyle]) { held[$0] }))
        XCTAssertEqual(look.style, .title)
        XCTAssertEqual(look.weight, .semibold)
        XCTAssertNotNil(TextMembers.look(ElementValues<TextContract>(changed: [.fontWeight]) { held[$0] }),
                        "the look where only its weight changed")

        var run = TextLook()
        run.weight = .bold
        XCTAssertEqual(run.over(look).style, .title, "a run given no style takes its label's")
        XCTAssertEqual(run.over(look).weight, .bold, "a run's own weight")
        XCTAssertEqual(TextLook().over(look).weight, .semibold, "a run given no weight takes its label's")
    }

    /// A label takes a new look's font, scaling and colour and keeps its own spacing, lines and decorations.
    func testALabelTakesAFontAndAColourKeepingItsLines() {
        var shown = TextLook()
        shown.letterSpacing = 2
        shown.lineHeight = 1.5
        shown.decorations = .underline
        var look = TextLook()
        look.style = .caption
        look.size = 11
        look.weight = .medium
        look.attributes = .italic
        look.attributesGiven = true
        look.family = "Menlo"
        look.color = Color.red.propValue
        look.scales = false
        shown.adopt(fontAndColorOf: look)

        var expected = look
        expected.letterSpacing = 2
        expected.lineHeight = 1.5
        expected.decorations = .underline
        XCTAssertEqual(shown, expected)
    }

    /// The size and the weight the tree gives stand over the style's; where it gives none, the style's stand, and
    /// with no style, the host's own.
    func testTheTreesSizeAndWeightStandOverTheStyles() {
        var look = TextLook()
        look.style = .title
        XCTAssertTrue(look.standing(styleSize: 28, styleWeight: .semibold) == (28, .semibold), "the style's")
        look.size = 13
        look.weight = .regular
        XCTAssertTrue(look.standing(styleSize: 28, styleWeight: .semibold) == (13, .regular), "the tree's")
        XCTAssertTrue(TextLook().standing(styleSize: nil, styleWeight: nil) == (nil, nil), "the host's own")
    }

    /// A weight is weighed by its number, 400 to 700, and a font's number reads as the weight nearest it.
    func testAWeightIsWeighedByItsNumber() {
        XCTAssertEqual(FontWeight.allCases.map(\.number), [400, 500, 600, 700])
        XCTAssertEqual([100, 400, 449, 450, 451, 510, 590, 650, 700, 900].map { FontWeight(nearest: Double($0)) },
                       [.regular, .regular, .regular, .regular, .medium, .medium, .semibold, .semibold, .bold, .bold])
    }

    /// Words follow the user's text size unless the tree says not: a run scales only where neither it nor its label
    /// says no.
    func testWordsScaleWithTheUsersTextSizeUnlessTheTreeSaysNot() {
        XCTAssertTrue(TextLook().scales, "on where nothing is said")
        var fixed = TextLook()
        fixed.scales = false
        XCTAssertFalse(TextLook().over(fixed).scales, "a run over a label that does not scale")
        XCTAssertFalse(fixed.over(TextLook()).scales, "a run that does not scale over a label that does")
    }

    /// Wrapped words held to a number of lines end the last with an ellipsis; words free of a limit, or kept to
    /// one line by their break, end with none of their own.
    func testWrappedWordsHeldToSomeLinesEndWithAnEllipsis() {
        XCTAssertTrue(LineBreak.wordWrap.endsWithEllipsis(maximum: 2))
        XCTAssertTrue(LineBreak.characterWrap.endsWithEllipsis(maximum: 1))
        XCTAssertFalse(LineBreak.wordWrap.endsWithEllipsis(maximum: nil))
        XCTAssertFalse(LineBreak.wordWrap.endsWithEllipsis(maximum: 0), "no more than nothing is no limit")
        XCTAssertFalse(LineBreak.noWrap.endsWithEllipsis(maximum: 2), "one line, cut")
        XCTAssertFalse(LineBreak.tailTruncation.endsWithEllipsis(maximum: 2), "its own ellipsis, on its one line")
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

    /// A field holds what the user typed in its case, then cut to its bound; words already so, or still being composed,
    /// are held as typed.
    func testAFieldHoldsTypedWordsInItsCaseWithinItsBound() {
        XCTAssertEqual(InputWords.held("Mixed", in: .uppercase, toBound: nil, composing: false), "MIXED")
        XCTAssertEqual(InputWords.held("Mixed", in: .lowercase, toBound: 3, composing: false), "mix")
        XCTAssertEqual(InputWords.held("Mixed", in: nil, toBound: 3, composing: false), "Mix")
        XCTAssertNil(InputWords.held("MIXED", in: .uppercase, toBound: 5, composing: false))
        XCTAssertNil(InputWords.held("Mixed", in: TextCase.none, toBound: nil, composing: false))
        XCTAssertNil(
            InputWords.held("zhongguo", in: .uppercase, toBound: 4, composing: true),
            "words an input method still composes are held as typed, until they are committed")
    }

    /// Words going into a field before they stand there - where a toolkit asks before it inserts - go in the field's
    /// case, cut to the characters that fit beside the words held: an emoji whole or not at all, none where the bound
    /// is reached.
    func testWordsGoingInAreCasedAndCutToWhatFitsBesideTheHeld() {
        XCTAssertEqual(InputWords.fitting("👍🏽b", beside: "a", toBound: 2), "👍🏽")
        XCTAssertEqual(InputWords.fitting("m", beside: "Ada", toBound: 3), "")
        XCTAssertNil(InputWords.fitting("d", beside: "A", toBound: 3))
        XCTAssertNil(InputWords.fitting("Adam", beside: "", toBound: nil))
        XCTAssertEqual(InputWords.fitting("ab", beside: "X", in: .uppercase, toBound: 2), "A")
        XCTAssertEqual(InputWords.fitting("Ada", beside: "", in: .lowercase, toBound: nil), "ada")
        XCTAssertNil(InputWords.fitting("ADA", beside: "", in: .uppercase, toBound: 5))
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
