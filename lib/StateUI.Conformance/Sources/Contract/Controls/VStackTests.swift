// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `VStackContract` on a host: a vertical stack stands its children one under another, in the order the tree gives
/// them, and again in the order the tree changes it to.
@_spi(Host) public enum VStackTests: ConformanceFamily {
    public static let name = "VStack"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("itsChildrenStandOneUnderAnotherInTheirOrder", covers: [
                Covered(VStackContract.self), Covered(ButtonContract.clicked),
            ]) { s in
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
        ]
    }
}
