// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `VStackContract` on a host: a vertical stack stands its children one under another, in the order the tree gives
/// them, and again in the order the tree changes it to; what it holds is measured at its own width.
@_spi(Host) public enum VStackTests: ConformanceFamily {
    public static let name = "VStack"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("VStack"),
            ConformanceCase("itsChildrenStandOneUnderAnotherInTheirOrder", proves: [
                Covered(VStackContract.self),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let swapped = State(wrappedValue: false)
                let (first, second) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        VStack {
                            ForEach(swapped.wrappedValue ? ["second", "first"] : ["first", "second"]) { name in
                                ColorBox(.red).width(40).height(name == "first" ? 20 : 30).horizontalAlignment(.start)
                                    .onEvent(ViewContract.frameChanged) {
                                        (name == "first" ? first : second).values.append($0)
                                    }
                                    .id(name)
                            }
                        }
                        Button("Swap").onClicked { swapped.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { second.values.last.map(FrameReport.place) == [0, 20, 40, 30] }
                s.expect(first.values.last.map(FrameReport.place), [0, 0, 40, 20], "the first on top")
                s.expect(second.values.last.map(FrameReport.place), [0, 20, 40, 30], "the second under it")

                try s.perform(.activate, on: s.element("change"))
                s.settle { first.values.last.map(FrameReport.place) == [0, 30, 40, 20] }
                s.expect(second.values.last.map(FrameReport.place), [0, 0, 40, 30], "in the order the tree changed")
                s.expect(first.values.last.map(FrameReport.place), [0, 30, 40, 20])
            },
            ConformanceCase("whatItHoldsIsMeasuredAtItsOwnWidth", proves: [Covered(VStackContract.self)]) { s in
                let (stack, line) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        VStack { Text(TextTests.long).lineBreak(.wordWrap) }.width(100)
                            .onEvent(ViewContract.frameChanged) { stack.values.append($0) }.id("stack")
                        Text("Words").onEvent(ViewContract.frameChanged) { line.values.append($0) }.id("line")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { !stack.values.isEmpty && !line.values.isEmpty }
                let one = line.values.last.map(FrameReport.size)?[1] ?? 0
                s.settle { (stack.values.last.map(FrameReport.size)?[1] ?? 0) > one * 2 }
                s.expect((stack.values.last.map(FrameReport.size)?[1] ?? 0) > one * 2, true,
                         "its words wrap at its hundred, not at the room it is offered")
            },
        ]
    }
}
