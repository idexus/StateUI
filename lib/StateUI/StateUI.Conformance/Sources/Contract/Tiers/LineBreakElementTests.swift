// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LineBreakElementContract` on a host: words too long for their room wrap, stand on one line, or are cut as the
/// tree says - a text's, a button's caption - and hold what the tree changes it to.
@_spi(Host) public enum LineBreakElementTests: ConformanceFamily {
    public static let name = "LineBreakElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("Text.wordsThatDoNotWrapStandOnOneLine", proves: [
                Covered(LineBreakElementContract.lineBreak, on: TextContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let wraps = State(wrappedValue: false)
                let frames = Received<[Double]>()
                s.start {
                    VStack {
                        Text(TextTests.long).lineBreak(wraps.wrappedValue ? .wordWrap : .noWrap).width(100)
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
            Aspects.holds(LineBreakElementContract.lineBreak, on: "Text", .wordWrap, then: .tailTruncation,
                          with: [Write(TextElementContract.text, TextTests.long)]),
            Aspects.holds(LineBreakElementContract.lineBreak, on: "Button", .wordWrap, then: .tailTruncation,
                          with: [Write(TextElementContract.text, "Words enough to break across more than one line")]),
        ] + TextTests.written.proving(LineBreakElementContract.self)
    }
}
