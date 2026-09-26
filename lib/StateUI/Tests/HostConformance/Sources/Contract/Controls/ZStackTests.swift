// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ZStackContract` on a host: its children stand one over another, each filling the room where it names no area, the
/// later over the earlier, and a press reaches the one in front.
@_spi(Host) public enum ZStackTests: ConformanceFamily {
    public static let name = "ZStack"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("itsChildrenStandOneOverAnotherInItsRoom", covers: [Covered(ZStackContract.self)]) { s in
                let (back, front) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        ZStack {
                            ColorBox(.red).onEvent(ViewContract.frameChanged) { back.values.append($0) }.id("back")
                            ColorBox(.blue).width(20).height(20).horizontalAlignment(.start).verticalAlignment(.start)
                                .onEvent(ViewContract.frameChanged) { front.values.append($0) }.id("front")
                        }
                        .width(60).height(40)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                s.settle { back.values.last.map(FrameReport.place) == [0, 0, 60, 40] }
                s.expect(back.values.last.map(FrameReport.place), [0, 0, 60, 40], "the whole room")
                s.expect(front.values.last.map(FrameReport.place), [0, 0, 20, 20], "over it, where its alignment puts it")
            },
            ConformanceCase("aPressReachesTheChildInFront", covers: [Covered(ZStackContract.self)]) { s in
                s.start {
                    VStack {
                        ZStack {
                            ColorBox(.red).id("back")
                            ColorBox(.blue).width(20).height(20).horizontalAlignment(.start).verticalAlignment(.start)
                                .id("front")
                        }
                        .width(60).height(40)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let (back, front) = (try s.element("back"), try s.element("front"))

                s.expect(try s.reaches(front, at: Point(10, 10)), true, "the later child, where it stands")
                s.expect(try s.reaches(back, at: Point(10, 10)), false, "not the one under it there")
                s.expect(try s.reaches(back, at: Point(40, 30)), true, "the earlier one beside it")
            },
        ]
    }
}
