// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextEditorContract` on a host: an editor's lines are heard as typed, within their bound.
@_spi(Host) public enum TextEditorTests: ConformanceFamily {
    public static let name = "TextEditor"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anEditorsLinesAreHeardWithinTheirBound", covers: [
                Covered(TextEditorContract.self), Covered(TextElementContract.text, on: TextEditorContract.self),
                Covered(InputViewContract.textChanged, on: TextEditorContract.self),
                Covered(InputViewContract.maximumLength, on: TextEditorContract.self),
            ]) { s in
                let words = State(wrappedValue: "")
                let heard = Received<String>()
                s.start {
                    VStack {
                        TextEditor(words.projectedValue).maximumLength(5).onTextChanged { heard.values.append($0) }
                            .id("editor")
                    }
                }
                let editor = try s.element("editor")

                try s.perform(.type("one\ntwo"), on: editor)
                s.settle { !heard.values.isEmpty }
                s.turn()

                s.expect(words.wrappedValue, "one\nt")
                s.expect(try s.held(TextElementContract.text, on: editor), "one\nt")
                s.expect(heard.values, ["one\nt"], "heard once, as the bound left the words")
            },
            ConformanceCase("anEditorGrowsWithItsWordsOnlyWhereItIsToldTo", covers: [
                Covered(TextEditorContract.growsWithText), Covered(ButtonContract.clicked),
            ]) { s in
                let words = State(wrappedValue: "one")
                let (growing, fixed) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        TextEditor(words.projectedValue).growsWithText(true).width(200)
                            .onEvent(ViewContract.frameChanged) { growing.values.append($0) }.id("growing")
                        TextEditor(words.projectedValue).growsWithText(false).width(200)
                            .onEvent(ViewContract.frameChanged) { fixed.values.append($0) }.id("fixed")
                        Button("More").onClicked { words.wrappedValue = "one\ntwo\nthree\nfour\nfive" }.id("change")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { !growing.values.isEmpty && !fixed.values.isEmpty }
                let before = (growing.values.last?[3] ?? 0, fixed.values.last?[3] ?? 0)

                try s.perform(.activate, on: s.element("change"))
                s.settle { (growing.values.last?[3] ?? 0) > before.0 * 2 }
                s.expect((growing.values.last?[3] ?? 0) > before.0 * 2, true, "grown with its words")
                s.expect(fixed.values.last?[3] ?? 0, before.1, within: 0.5, "a line's height, however many it holds")
            },
            Aspects.holds(TextEditorContract.growsWithText, on: "TextEditor", false, then: true),
        ]
    }
}
