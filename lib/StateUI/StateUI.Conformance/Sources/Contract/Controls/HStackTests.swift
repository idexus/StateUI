// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `HStackContract` on a host: a horizontal stack stands its children side by side, in the order the tree gives them,
/// a child the tree takes away leaves its room to the next, and a row short of room takes it from its words.
@_spi(Host) public enum HStackTests: ConformanceFamily {
    public static let name = "HStack"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("HStack"),
            ConformanceCase("itsChildrenStandSideBySideInTheirOrder", proves: [
                Covered(HStackContract.self),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let both = State(wrappedValue: true)
                let second = Received<[Double]>()
                s.start {
                    VStack {
                        HStack {
                            if both.wrappedValue {
                                Rectangle()
                                    .fill(.red)
                                    .width(30)
                                    .height(20)
                                    .id("first")
                            }
                            Rectangle()
                                .fill(.blue)
                                .width(40)
                                .height(20)
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
            ConformanceCase("aRowShortOfRoomTakesItFromItsWords", proves: [Covered(HStackContract.self)]) { s in
                let (words, box) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        HStack {
                            Text("Words far longer than the row they stand in has room for")
                                .maximumLines(1)
                                .onEvent(ViewContract.frameChanged) { words.values.append($0) }
                            Rectangle()
                                .fill(.blue)
                                .width(60)
                                .height(20)
                                .onEvent(ViewContract.frameChanged) { box.values.append($0) }
                        }
                        .spacing(0)
                        .width(200)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                // Across alone: how tall the words stand is each toolkit's.
                let across = { (report: [Double]?) in report.map(FrameReport.place).map { [$0[0], $0[2]] } }
                s.settle { across(box.values.last) == [140, 60] && across(words.values.last) == [0, 140] }
                s.expect(across(box.values.last), [140, 60], "the box whole, at the row's end")
                s.expect(across(words.values.last), [0, 140], "the words in what it leaves")
            },
        ]
    }
}
