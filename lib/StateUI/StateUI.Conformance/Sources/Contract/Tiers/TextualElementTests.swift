// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextualElementContract` on a host: the tree's words, changed as the tree changes them, in the case the tree asks for -
/// each case made for every element wearing the tier.
@_spi(Host) public enum TextualElementTests: ConformanceFamily {
    public static let name = "TextualElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(TextualElementContract.self).flatMap { element in [words(element), cased(element)] }
    }

    /// An element shows the words the tree gives it, and the words the tree changes them to.
    @MainActor
    static func words(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).showsTheWordsTheTreeGives", proves: [
            Covered(TextualElementContract.text, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let words = State(wrappedValue: "Some words")
            s.start {
                Specimens.page(element, [Write(TextualElementContract.text, words.wrappedValue)], beside: [
                    Button("Change").onClicked { words.wrappedValue = "Other words" }.id("change"),
                ])
            }
            let view = try s.specimen(element)
            s.expect(try s.held(TextualElementContract.text, on: view), "Some words")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(TextualElementContract.text, on: view) == "Other words" }
            s.expect(try s.held(TextualElementContract.text, on: view), "Other words")
        }
    }

    /// An element shows its words in the case the tree asks for.
    @MainActor
    static func cased(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).showsItsWordsInTheirCase", proves: [
            Covered(TextualElementContract.text, on: element), Covered(TextualElementContract.textCase, on: element),
        ]) { s in
            s.start {
                Specimens.page(element, [
                    Write(TextualElementContract.text, "Mixed Words"), Write(TextualElementContract.textCase, TextCase.uppercase),
                ])
            }
            s.expect(try s.held(TextualElementContract.text, on: s.specimen(element)), "MIXED WORDS")
        }
    }
}
