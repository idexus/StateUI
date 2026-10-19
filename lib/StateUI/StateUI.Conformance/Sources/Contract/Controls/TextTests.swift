// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextContract` on a host: a label shows its words, wraps or cuts them as the tree says, shows no more lines than
/// its maximum, and stands its words down its room where the tree aligns them.
@_spi(Host) public enum TextTests: ConformanceFamily {
    public static let name = "Text"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Text"),
            Aspects.holds(TextContract.verticalTextAlignment, on: "Text", .start, then: .end, with: Words.on("Text")),
            ConformanceCase("wordsTheTreeMakesSelectableCanBeSelected", proves: [
                Covered(TextContract.isSelectable, on: "Text"),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let selectable = State(wrappedValue: false)
                s.start {
                    VStack {
                        Text("Some words").isSelectable(selectable.wrappedValue).id("label")
                        Button("Change").onClicked { selectable.wrappedValue.toggle() }.id("change")
                    }
                }
                s.expect(try s.held(TextContract.isSelectable, on: s.element("label")), false, "words not to select")
                s.expect(try s.held(TextualElementContract.text, on: s.element("label")), "Some words")

                // Another value makes the text anew: it is looked for again.
                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(TextContract.isSelectable, on: s.element("label")) == true }
                s.expect(try s.held(TextContract.isSelectable, on: s.element("label")), true, "words to select")
                s.expect(try s.held(TextualElementContract.text, on: s.element("label")), "Some words",
                         "the same words, selectable")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(TextContract.isSelectable, on: s.element("label")) == false }
                s.expect(try s.held(TextContract.isSelectable, on: s.element("label")), false, "not to select again")
            },
            ConformanceCase("aTextShowsItsWords", proves: [
                Covered(TextContract.self),
            ], needs: [Covered(TextualElementContract.text, on: "Text")]) { s in
                s.start { VStack { Text("Some words").id("label") } }

                s.expect(try s.held(TextualElementContract.text, on: s.element("label")), "Some words")
            },
            ConformanceCase("noMoreLinesStandThanItsMaximum", proves: [
                Covered(TextContract.maximumLines), Covered(TextContract.lineBreak),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let lines = State(wrappedValue: 1)
                let frames = Received<[Double]>()
                s.start {
                    VStack {
                        Text(Self.long).lineBreak(.wordWrap).maximumLines(lines.wrappedValue).width(100)
                            .onEvent(ViewContract.frameChanged) { frames.values.append($0) }.id("label")
                        Button("More").onClicked { lines.wrappedValue = 3 }.id("change")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { !frames.values.isEmpty }
                let one = frames.values.last.map(FrameReport.size)?[1] ?? 0

                try s.perform(.activate, on: s.element("change"))
                s.settle { (frames.values.last.map(FrameReport.size)?[1] ?? 0) > one * 2 }
                s.expect((frames.values.last.map(FrameReport.size)?[1] ?? 0) > one * 2, true,
                         "three lines stand where one stood")
            },
            ConformanceCase("wordsThatDoNotWrapStandOnOneLine", proves: [
                Covered(TextContract.lineBreak),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let wraps = State(wrappedValue: false)
                let frames = Received<[Double]>()
                s.start {
                    VStack {
                        Text(Self.long).lineBreak(wraps.wrappedValue ? .wordWrap : .noWrap).width(100)
                            .onEvent(ViewContract.frameChanged) { frames.values.append($0) }.id("label")
                        Button("Wrap").onClicked { wraps.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { !frames.values.isEmpty }
                let one = frames.values.last.map(FrameReport.size)?[1] ?? 0

                try s.perform(.activate, on: s.element("change"))
                s.settle { (frames.values.last.map(FrameReport.size)?[1] ?? 0) > one * 2 }
                s.expect((frames.values.last.map(FrameReport.size)?[1] ?? 0) > one * 2, true, "wrapped over lines")
            },
            Aspects.holds(TextContract.lineBreak, on: "Text", .wordWrap, then: .tailTruncation,
                          with: [Write(TextualElementContract.text, Self.long)]),
            Aspects.holds(TextContract.maximumLines, on: "Text", 2, then: 1,
                          with: [Write(TextualElementContract.text, Self.long)]),
        ]
    }

    /// Words enough to take several lines of a narrow label.
    static let long = "Words enough to take several lines of a label a hundred wide, and more than that"
}
