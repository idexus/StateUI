// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LabelContract` on a host: a label shows its words, wraps or cuts them as the tree says, and shows no more lines
/// than its maximum.
@_spi(Host) public enum LabelTests: ConformanceFamily {
    public static let name = "Label"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aLabelShowsItsWords", covers: [
                Covered(LabelContract.self), Covered(TextElementContract.text, on: "Label"),
            ]) { s in
                s.start { VStack { Label("Some words").id("label") } }

                s.expect(try s.held(TextElementContract.text, on: s.element("label")), "Some words")
            },
            ConformanceCase("noMoreLinesStandThanItsMaximum", covers: [
                Covered(LabelContract.maximumLines), Covered(LabelContract.lineBreak), Covered(ButtonContract.clicked),
            ]) { s in
                let lines = State(wrappedValue: 1)
                let frames = Received<[Double]>()
                s.start {
                    VStack {
                        Label(Self.long).lineBreak(.wordWrap).maximumLines(lines.wrappedValue).width(100)
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
            ConformanceCase("wordsThatDoNotWrapStandOnOneLine", covers: [
                Covered(LabelContract.lineBreak), Covered(ButtonContract.clicked),
            ]) { s in
                let wraps = State(wrappedValue: false)
                let frames = Received<[Double]>()
                s.start {
                    VStack {
                        Label(Self.long).lineBreak(wraps.wrappedValue ? .wordWrap : .noWrap).width(100)
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
            Aspects.holds(LabelContract.lineBreak, on: "Label", .wordWrap, then: .tailTruncation,
                          with: [Write(TextElementContract.text, Self.long)]),
            Aspects.holds(LabelContract.maximumLines, on: "Label", 2, then: 1,
                          with: [Write(TextElementContract.text, Self.long)]),
        ]
    }

    /// Words enough to take several lines of a narrow label.
    static let long = "Words enough to take several lines of a label a hundred wide, and more than that"
}
