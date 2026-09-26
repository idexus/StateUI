// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextElementContract` on a host: the tree's words, changed as the tree changes them, in the case the tree asks for -
/// each case made for every element wearing the tier.
@_spi(Host) public enum TextElementTests: ConformanceFamily {
    public static let name = "TextElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(TextElementContract.self).flatMap { element in [words(element), cased(element)] }
    }

    /// An element shows the words the tree gives it, and the words the tree changes them to.
    static func words(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).showsTheWordsTheTreeGives", covers: [
            Covered(TextElementContract.text, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let words = State(wrappedValue: "Some words")
            s.start {
                VStack {
                    Specimens.page(element, [Write(TextElementContract.text, words.wrappedValue)])
                    Button("Change").onClicked { words.wrappedValue = "Other words" }.id("change")
                }
            }
            let view = try s.specimen(element)
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
                Specimens.page(element, [
                    Write(TextElementContract.text, "Mixed Words"), Write(TextElementContract.textCase, TextCase.uppercase),
                ])
            }
            s.expect(try s.held(TextElementContract.text, on: s.specimen(element)), "MIXED WORDS")
        }
    }
}
