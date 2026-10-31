// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `HStackContract` on a host: a horizontal stack stands its children side by side, in the order the tree gives them,
/// a child the tree takes away leaves its room to the next, a row short of room takes it from its words, and a row that
/// wraps goes on onto further lines, each standing where its line alignment says.
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
            ConformanceCase("aRowThatWrapsGoesOnOntoFurtherLines", proves: [
                Covered(HStackContract.wraps), Covered(HStackContract.rowSpacing),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let step = State(wrappedValue: 0)
                let third = Received<[Double]>()
                s.start {
                    VStack {
                        HStack {
                            ForEach(0..<4, id: \.self) { index in
                                Rectangle()
                                    .fill(.blue)
                                    .width(60)
                                    .height(20)
                                    .onEvent(ViewContract.frameChanged) { if index == 2 { third.values.append($0) } }
                            }
                        }
                        .wraps(step.wrappedValue < 2)
                        .spacing(10)
                        .rowSpacing(step.wrappedValue == 0 ? 6 : 16)
                        .width(150)
                        Button("Next").onClicked { step.wrappedValue += 1 }.id("change")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let place = { third.values.last.map(FrameReport.place) }
                s.settle { place() == [0, 26, 60, 20] }
                s.expect(place(), [0, 26, 60, 20], "two on a line of 150, the third starting the next 6 below")

                try s.perform(.activate, on: s.element("change"))
                s.settle { place() == [0, 36, 60, 20] }
                s.expect(place(), [0, 36, 60, 20], "the lines the spacing the tree changed it to apart")

                try s.perform(.activate, on: s.element("change"))
                s.settle { place() == [140, 0, 60, 20] }
                s.expect(place(), [140, 0, 60, 20], "unwrapped, on one line past its room")
            },
            ConformanceCase("aWrappedRowsLinesStandWhereItsLineAlignmentSays", proves: [
                Covered(HStackContract.lineAlignment),
            ], needs: [Covered(HStackContract.wraps), Covered(ButtonContract.clicked)]) { s in
                let alignment = State(wrappedValue: TextAlignment.center)
                let third = Received<[Double]>()
                s.start {
                    VStack {
                        HStack {
                            ForEach(0..<3, id: \.self) { index in
                                Rectangle()
                                    .fill(.blue)
                                    .width(60)
                                    .height(20)
                                    .onEvent(ViewContract.frameChanged) { if index == 2 { third.values.append($0) } }
                            }
                        }
                        .wraps(true)
                        .lineAlignment(alignment.wrappedValue)
                        .spacing(10)
                        .rowSpacing(6)
                        .width(150)
                        Button("End").onClicked { alignment.wrappedValue = .end }.id("end")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let place = { third.values.last.map(FrameReport.place) }
                s.settle { place() == [45, 26, 60, 20] }
                s.expect(place(), [45, 26, 60, 20], "the second line, one of 60 in 150, in the middle")

                try s.perform(.activate, on: s.element("end"))
                s.settle { place() == [90, 26, 60, 20] }
                s.expect(place(), [90, 26, 60, 20], "at the end")
            },
        ]
    }
}
