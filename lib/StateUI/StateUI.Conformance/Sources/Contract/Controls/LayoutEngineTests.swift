// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LayoutEngineContract` on a host: each view stands where the arithmetic puts it, the arithmetic is handed the room
/// the layout was given and handed it again when it changes, the layout takes no size from its views, and a scroll
/// comes to rest on a snap target.
@_spi(Host) public enum LayoutEngineTests: ConformanceFamily {
    public static let name = "LayoutEngine"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("LayoutEngine"),
            ConformanceCase("eachViewStandsWhereItsArithmeticPutsIt", proves: [Covered(LayoutEngineContract.self)]) { s in
                let (first, second) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        LayoutEngine([0, 1]) { index in
                            Rectangle(index == 0 ? .red : .blue)
                                .onEvent(ViewContract.frameChanged) { (index == 0 ? first : second).values.append($0) }
                        } placements: { _, _ in
                            [Placement(Rect(0, 0, 20, 10)), Placement(Rect(30, 10, 20, 20))]
                        }
                        .width(60).height(40)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                // The second's corner from the first's: where the layout itself stands in the window is no matter.
                let apart = {
                    guard let one = first.values.last.map(FrameReport.inContent),
                          let two = second.values.last.map(FrameReport.inContent)
                    else { return [Double]() }
                    return [two[0] - one[0], two[1] - one[1]]
                }
                s.settle { apart() == [30, 10] }
                s.expect(first.values.last.map(FrameReport.size), [20, 10], "the first at the size its placement gives")
                s.expect(second.values.last.map(FrameReport.size), [20, 20], "the second at its own")
                s.expect(apart(), [30, 10], "and where the second's placement stands it from the first")
            },
            ConformanceCase("itsArithmeticIsHandedItsRoomAgainWhenItChanges", proves: [Covered(LayoutEngineContract.self)]) { s in
                let rooms = Received<Rect>()
                let width = State(wrappedValue: 60.0)
                s.start {
                    VStack {
                        LayoutEngine([0]) { _ in Rectangle(.red) } placements: { room, _ in
                            rooms.values.append(room)
                            return [Placement(Rect(0, 0, 10, 10))]
                        }
                        .width(width.projectedValue).height(40)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                s.settle { rooms.values.last == Rect(0, 0, 60, 40) }
                s.expect(rooms.values.last, Rect(0, 0, 60, 40), "the room it was given, from its own top left")

                width.wrappedValue = 90
                s.settle { rooms.values.last == Rect(0, 0, 90, 40) }
                s.expect(rooms.values.last, Rect(0, 0, 90, 40), "and the new room it was given")
            },
            ConformanceCase("itHasNoSizeOfItsOwn", proves: [Covered(LayoutEngineContract.self)]) { s in
                let (above, below) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        Rectangle(.blue).width(20).height(10).onEvent(ViewContract.frameChanged) { above.values.append($0) }
                        LayoutEngine([0]) { _ in Rectangle(.red).width(40).height(40) } placements: { room, _ in
                            [Placement(room)]
                        }
                        Rectangle(.green).width(20).height(10).onEvent(ViewContract.frameChanged) { below.values.append($0) }
                    }
                    .spacing(0)
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                // How far below the first view the last stands: the first's height alone where the layout between
                // them takes none.
                let apart = {
                    guard let one = above.values.last.map(FrameReport.inContent),
                          let two = below.values.last.map(FrameReport.inContent)
                    else { return -1.0 }
                    return two[1] - one[1]
                }
                s.settle { apart() == 10 }
                s.expect(apart(), 10, "the view below right under the one above, whatever the layout's view needs")
            },
            ConformanceCase("aScrollComesToRestOnTheNearestSnapTarget", proves: [Covered(LayoutEngineContract.self)]) { s in
                let clock = TestClock()
                let phase = State(wrappedValue: 0.0)
                s.start(clock: clock) {
                    VStack {
                        LayoutEngine([0, 1, 2]) { _ in Rectangle(.red) } placements: { _, phase in
                            (0..<3).map { Placement(Rect((Double($0) - phase) * 50 + 40, 0, 20, 20)) }
                        }
                        .phase(phase.projectedValue)
                        .input(.scroll(.horizontal, pointsPerUnit: 100))
                        .snapTargets([0, 1, 2])
                        .width(100).height(40)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                // The scroll stands once its reader knows the room, and is laid out where the phase says before the
                // hand comes: a scroller's first layout puts it where the tree says.
                s.settle { (try? s.element(ofType: .scrollView)) != nil }
                let scroller = try s.element(ofType: .scrollView)
                var time = 0.0
                @MainActor func frames(until end: Double) {
                    while time < end {
                        time += 16
                        clock.now = time
                        s.frame()
                    }
                }
                s.turn()
                frames(until: 320)
                s.turn()

                try s.perform(.scroll(to: Point(140, 0)), on: scroller)
                s.turn()
                frames(until: 1_600)

                s.expect(phase.wrappedValue, 1, "the nearest target to where the hand left it")
            },
        ]
    }
}
