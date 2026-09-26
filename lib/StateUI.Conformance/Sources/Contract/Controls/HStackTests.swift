// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `HStackContract` on a host: a horizontal stack stands its children side by side, in the order the tree gives them,
/// and a child the tree takes away leaves its room to the next.
@_spi(Host) public enum HStackTests: ConformanceFamily {
    public static let name = "HStack"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("itsChildrenStandSideBySideInTheirOrder", covers: [
                Covered(HStackContract.self), Covered(ButtonContract.clicked),
            ]) { s in
                let both = State(wrappedValue: true)
                let second = Received<[Double]>()
                s.start {
                    VStack {
                        HStack {
                            if both.wrappedValue { ColorBox(.red).width(30).height(20).id("first") }
                            ColorBox(.blue).width(40).height(20)
                                .onEvent(ViewContract.frameChanged) { second.values.append($0) }
                                .id("second")
                        }
                        Button("Take").onClicked { both.wrappedValue = false }.id("change")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { second.values.last.map(FrameReport.place) == [30, 0, 40, 20] }
                s.expect(second.values.last.map(FrameReport.place), [30, 0, 40, 20], "beside the first")

                try s.perform(.activate, on: s.element("change"))
                s.settle { second.values.last.map(FrameReport.place) == [0, 0, 40, 20] }
                s.expect(second.values.last.map(FrameReport.place), [0, 0, 40, 20], "in the room the first left")
            },
        ]
    }
}
