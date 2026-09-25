// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What every element showing words shows: the tree's words, changed as the tree changes them, in the case the tree
/// asks for - each case made for every element wearing the tier.
@_spi(Host) public enum Words: ConformanceFamily {
    public static let name = "Words"

    public static var cases: [ConformanceCase] {
        var cases: [ConformanceCase] = []
        for element in Specimens.wearing(TextElementContract.self) {
            cases.append(words(element))
            cases.append(cased(element))
        }
        return cases
    }

    /// An element shows the words the tree gives it, and the words the tree changes them to.
    static func words(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).showsTheWordsTheTreeGives", covers: [
            Covered(TextElementContract.text, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let words = State(wrappedValue: "Some words")
            s.start {
                VStack {
                    specimen(element, [Write(TextElementContract.text, words.wrappedValue)])
                    Button("Change").onClicked { words.wrappedValue = "Other words" }.id("change")
                }
            }
            let view = try s.element("specimen")
            s.expect(try s.held(TextElementContract.text, on: view), "Some words")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(TextElementContract.text, on: view) == "Other words" }
            s.expect(try s.held(TextElementContract.text, on: view), "Other words")
        }
    }

    /// An element shows its words in the case the tree asks for.
    static func cased(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).showsItsWordsInTheirCase", covers: [
            Covered(TextElementContract.text, on: element), Covered(TextElementContract.textCase, on: element),
        ]) { s in
            s.start {
                VStack {
                    specimen(element, [Write(TextElementContract.text, "Mixed Words"),
                                       Write(TextElementContract.textCase, TextCase.uppercase)])
                }
            }
            s.expect(try s.held(TextElementContract.text, on: s.element("specimen")), "MIXED WORDS")
        }
    }

    /// `element`'s specimen wearing `writes`.
    private static func specimen(_ element: String, _ writes: [any Worn]) -> any View {
        Specimens.make(element, Dressing(writes)) ?? Label("no specimen of \(element)")
    }
}
