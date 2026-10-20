// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ScrollViewContract` on a host: its content takes its width down and its own width across; an offset the tree
/// writes moves it within reach, heard by nobody; the user's scroll lands on the state on the display's frame, heard
/// each way it goes, and rests once; its bars show as the tree says.
@_spi(Host) public enum ScrollViewTests: ConformanceFamily {
    public static let name = "ScrollView"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("ScrollView"),
            ConformanceCase("scrollingDownItsContentTakesItsWidth", proves: [
                Covered(ScrollViewContract.orientation),
            ]) { s in
                let frames = Received<[Double]>()
                s.start {
                    VStack {
                        ScrollView {
                            Rectangle().fill(.red).height(2000).onEvent(ViewContract.frameChanged) { frames.values.append($0) }
                        }
                        .orientation(.vertical)
                        .width(200).height(100)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                s.settle { frames.values.last.map(FrameReport.size) == [200, 2000] }
                s.expect(frames.values.last.map(FrameReport.size), [200, 2000], "the scroller's width, its own height")
            },
            ConformanceCase("scrollingAcrossItsContentKeepsItsOwnWidth", proves: [
                Covered(ScrollViewContract.orientation),
            ]) { s in
                let frames = Received<[Double]>()
                s.start {
                    VStack {
                        ScrollView {
                            Rectangle().fill(.red).width(3000).height(40)
                                .onEvent(ViewContract.frameChanged) { frames.values.append($0) }
                        }
                        .orientation(.horizontal)
                        .width(200).height(100)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                s.settle { frames.values.last.map(FrameReport.size)?.first == 3000 }
                s.expect(frames.values.last.map(FrameReport.size)?.first, 3000, "its own width across")
            },
            ConformanceCase("anOffsetTheTreeWritesMovesItWithinReach", proves: [
                Covered(ScrollViewContract.scrollOffset),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let offset = State(wrappedValue: Point(0, 0))
                s.start(reducesMotion: true) {
                    VStack {
                        Button("Down").onClicked { offset.wrappedValue = Point(0, 300) }.id("down")
                        Button("Past").onClicked { offset.wrappedValue = Point(0, 5000) }.id("past")
                        ScrollView { Rectangle().fill(.red).height(2000) }
                            .scrollOffset(offset.projectedValue)
                            .width(200).height(500).id("scroller")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let scroller = try s.element("scroller")

                try s.perform(.activate, on: s.element("down"))
                try s.settle { try s.held(ScrollViewContract.scrollOffset, on: scroller) == Point(0, 300) }
                s.expect(try s.held(ScrollViewContract.scrollOffset, on: scroller), Point(0, 300))

                try s.perform(.activate, on: s.element("past"))
                try s.settle { try s.held(ScrollViewContract.scrollOffset, on: scroller) == Point(0, 1500) }
                s.expect(try s.held(ScrollViewContract.scrollOffset, on: scroller), Point(0, 1500), "no further than its end")
            },
            ConformanceCase("theUsersScrollLandsOnTheFrameAndRestsOnce", proves: [
                Covered(ScrollViewContract.scrollOffset), Covered(ScrollViewContract.scrollStopped),
            ]) { s in
                let clock = TestClock()
                let offset = State(wrappedValue: Point(0, 0))
                let rests = Received<Int>()
                s.start(clock: clock) {
                    VStack {
                        ScrollView { Rectangle().fill(.red).height(2000) }
                            .scrollOffset(offset.projectedValue)
                            .onScrollStopped { rests.values.append(1) }
                            .width(200).height(500).id("scroller")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let scroller = try s.element("scroller")

                try s.perform(.scroll(to: Point(0, 200)), on: scroller)
                s.turn()
                s.frames(of: clock, until: 400)

                s.expect(offset.wrappedValue, Point(0, 200), "on the state, where it went")
                s.expect(rests.values, [1], "at rest once")
            },
            ConformanceCase("theUsersScrollAcrossLandsOnTheState", proves: [
                Covered(ScrollViewContract.scrollOffset), Covered(ScrollViewContract.orientation),
            ]) { s in
                let clock = TestClock()
                let offset = State(wrappedValue: Point(0, 0))
                s.start(clock: clock) {
                    VStack {
                        ScrollView { Rectangle().fill(.red).width(3000).height(40) }
                            .orientation(.horizontal)
                            .scrollOffset(offset.projectedValue)
                            .width(200).height(100).id("scroller")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let scroller = try s.element("scroller")

                try s.perform(.scroll(to: Point(300, 0)), on: scroller)
                s.turn()
                s.frames(of: clock, until: 400)

                s.expect(offset.wrappedValue, Point(300, 0))
            },
            Aspects.holds(ScrollViewContract.verticalScrollIndicator, on: "ScrollView", .visible, then: .never),
            Aspects.holds(ScrollViewContract.horizontalScrollIndicator, on: "ScrollView", .visible, then: .never,
                          with: [Write(ScrollViewContract.orientation, ScrollOrientation.horizontal)]),
        ]
    }
}
