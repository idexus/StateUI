// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LayoutEngineContract` on a host: each view stands where the arithmetic puts it, the arithmetic is handed the room
/// the layout was given and handed it again when it changes, the layout takes no size from its views, the phase the
/// program sends travels there and is awaited - each axis of it on its own - and a scroll comes to rest on a snap
/// target.
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
            ConformanceCase("thePhaseTravelsWhereTheProgramSendsIt", proves: [
                Covered(LayoutEngineContract.phase),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let clock = TestClock()
                let phase = State(wrappedValue: 0.0)
                let (handed, arrived) = (Received<Double>(), Received<Bool>())
                s.start(clock: clock) {
                    VStack {
                        LayoutEngine([0]) { _ in Rectangle(.red) } placements: { _, phase in
                            handed.values.append(phase)
                            return [Placement(Rect(phase * 10, 0, 20, 20))]
                        }
                        .phase(phase.projectedValue)
                        .motion(.eased(.milliseconds(400), .linear))
                        .width(100).height(40)
                        Button("Go").onClicked(gate: .ignoreWhileRunning) {
                            arrived.values.append(try await phase.projectedValue.journey.move(to: 4).arrived())
                        }
                        .id("go")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { handed.values.last == 0 }

                var time = 0.0
                @MainActor func frames(until end: Double) {
                    while time < end {
                        time += 16
                        clock.now = time
                        s.frame()
                    }
                }
                // The handler runs as the host runs a run's first steps; the clock waits for it.
                try s.perform(.activate, on: s.element("go"))
                s.settle { phase.wrappedValue == 4 }
                frames(until: 200)
                let between = handed.values.last ?? 0
                s.expect(between > 0 && between < 4, true, "on its way half its time in, never at the destination at once")

                frames(until: 1_000)
                s.settle { arrived.values == [true] }
                s.expect(handed.values.last, 4, "where the program sent it")
                s.expect(arrived.values, [true], "and a move of it awaited until it arrived")
            },
            ConformanceCase("eachAxisOfThePhaseTravelsOnItsOwn", proves: [
                Covered(LayoutEngineContract.phase),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let clock = TestClock()
                let phase = State(wrappedValue: Orbit())
                let (handed, arrived) = (Received<Orbit>(), Received<Bool>())
                s.start(clock: clock) {
                    VStack {
                        LayoutEngine([0]) { _ in Rectangle(.red) } placements: { _, phase in
                            handed.values.append(phase)
                            return [Placement(Rect(phase.turn * 10, 0, 20 * phase.zoom, 20))]
                        }
                        .phase(phase.projectedValue)
                        .motion(.eased(.milliseconds(400), .linear))
                        .width(100).height(40)
                        Button("Turn").onClicked(gate: .ignoreWhileRunning) {
                            arrived.values.append(try await phase.projectedValue.journey.move(to: Orbit(turn: 4)).arrived())
                        }
                        .id("turn")
                        Button("Zoom").onClicked { phase.wrappedValue.zoom = 2 }
                            .id("zoom")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { handed.values.last == Orbit() }

                var time = 0.0
                @MainActor func frames(until end: Double) {
                    while time < end {
                        time += 16
                        clock.now = time
                        s.frame()
                    }
                }
                try s.perform(.activate, on: s.element("turn"))
                s.settle { phase.wrappedValue.turn == 4 }
                frames(until: 200)
                try s.perform(.activate, on: s.element("zoom"))
                s.settle { phase.wrappedValue.zoom == 2 }

                // The turn's 400 ms end, the zoom sent halfway through it still on its way.
                frames(until: 432)
                s.settle { arrived.values == [true] }
                s.expect(handed.values.last?.turn, 4, "the turn arrived when it was due, the zoom sent meanwhile")
                s.expect(handed.values.last.map { $0.zoom > 1 && $0.zoom < 2 }, true, "the zoom on its own way")
                s.expect(arrived.values, [true], "and the turn's move awaited to its end")

                frames(until: 1_000)
                s.expect(handed.values.last, Orbit(turn: 4, zoom: 2), "both where they were sent")
            },
            ConformanceCase("theHandMovesTheRunAndRestsItOnTheNearestTarget", proves: [
                Covered(LayoutEngineContract.handMoved), Covered(LayoutEngineContract.handAxis),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try handLayout(s, clock: clock, phase: phase)

                // 140 points to the left is 1.4 targets on: let go still, it rests on the nearest.
                try s.perform(.sweep(by: Point(-140, 0), speed: .zero), on: layout)
                frames(s, clock, until: 1_600)

                s.expect(phase.wrappedValue, 1, "the target nearest where the hand let it go")
            },
            ConformanceCase("aThrowGoesOnToTheTargetNearestWhereItWouldEnd", proves: [
                Covered(LayoutEngineContract.handMoved),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try handLayout(s, clock: clock, phase: phase)

                // Let go at 2,250 points a second, 22.5 targets a second, the throw carries it three targets on.
                try s.perform(.sweep(by: Point(-10, 0), speed: Point(-2_250, 0)), on: layout)
                frames(s, clock, until: 1_600)

                s.expect(phase.wrappedValue, 3, "not the nearest to where the hand let go, but to where the throw ends")
            },
            ConformanceCase("aWheelsNotchStepsTheRunToTheNextTarget", proves: [
                Covered(LayoutEngineContract.handStepped),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try handLayout(s, clock: clock, phase: phase)

                // A notch is a step, however far a target stands: one on, then two more.
                try s.perform(.notch(by: Point(-1, 0)), on: layout)
                frames(s, clock, until: 800)
                s.expect(phase.wrappedValue, 1, "the next target")

                try s.perform(.notch(by: Point(-2, 0)), on: layout)
                frames(s, clock, until: 1_600)
                s.expect(phase.wrappedValue, 3, "a target a notch")
            },
            ConformanceCase("aHandAcrossItsAxisLeavesTheRun", proves: [Covered(LayoutEngineContract.handAxis)]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try handLayout(s, clock: clock, phase: phase)

                try s.perform(.sweep(by: Point(0, -140), speed: Point(0, -600)), on: layout)
                frames(s, clock, until: 1_600)

                s.expect(phase.wrappedValue, 0, "a hand moving down is not the run's, which moves across")
            },
            ConformanceCase("aPressHeldTakesTheViewUnderItToTheHand", proves: [
                Covered(LayoutEngineContract.itemDrag), Covered(LayoutEngineContract.itemMoved),
            ]) { s in
                let (clock, phase, told) = (TestClock(), State(wrappedValue: 0.0), Received<String>())
                let layout = try itemLayout(s, clock: clock, phase: phase, begins: .held, told: told)

                // The middle view stands from 30 to 50 across: a press on it held past a long press is its.
                try s.perform(.pressDown(at: Point(40, 20)), on: layout)
                frames(s, clock, until: clock.now + 600)
                try s.perform(.drag(to: Point(70, 30)), on: layout)
                frames(s, clock, until: clock.now + 48)
                try s.perform(.lift(at: Point(70, 30)), on: layout)
                frames(s, clock, until: clock.now + 600)

                s.expect(told.values.first, "1 at 40,20", "the view under the press, where it went down")
                s.expect(told.values.last, "1 at 70,30", "and where the hand took it")
                s.expect(phase.wrappedValue, 0, "the run stands")
            },
            ConformanceCase("aFirstMoveAcrossTakesTheViewUnderThePress", proves: [
                Covered(LayoutEngineContract.itemDrag), Covered(LayoutEngineContract.itemMoved),
            ]) { s in
                let (clock, phase, told) = (TestClock(), State(wrappedValue: 0.0), Received<String>())
                let layout = try itemLayout(s, clock: clock, phase: phase, begins: .across, told: told)

                try s.perform(.pressDown(at: Point(40, 15)), on: layout)
                try s.perform(.drag(to: Point(42, 35)), on: layout)
                frames(s, clock, until: clock.now + 48)
                try s.perform(.lift(at: Point(42, 35)), on: layout)
                frames(s, clock, until: clock.now + 600)

                s.expect(told.values.first, "1 at 40,15", "the view under the press")
                s.expect(told.values.last, "1 at 42,35", "moved down with the hand")
                s.expect(phase.wrappedValue, 0, "the run stands")
            },
            ConformanceCase("aViewLetGoFarEnoughIsDismissed", proves: [Covered(LayoutEngineContract.itemMoved)]) { s in
                let (clock, phase, told) = (TestClock(), State(wrappedValue: 0.0), Received<String>())
                let layout = try itemLayout(s, clock: clock, phase: phase, begins: .across, told: told, dismissing: true)

                try s.perform(.pressDown(at: Point(40, 15)), on: layout)
                try s.perform(.drag(to: Point(40, 38)), on: layout)
                frames(s, clock, until: clock.now + 48)
                try s.perform(.lift(at: Point(40, 38)), on: layout)
                frames(s, clock, until: clock.now + 1_000)
                s.settle { told.values.last == "1 dismissed" }

                s.expect(told.values.last, "1 dismissed", "flown out of the room, its item told")
            },
        ]
    }
}

/// A layout of three views a hand moves across, whose views it takes by themselves as `begins` says - each told to
/// `told` with where the hand is, and one let go twenty points down dismissed where `dismissing` - its run on
/// `clock`: the layout's element, once the room is told.
@MainActor
private func itemLayout(
    _ s: Session, clock: TestClock, phase: State<Double>, begins: ItemDragStart, told: Received<String>,
    dismissing: Bool = false
) throws -> MountedElement {
    s.start(clock: clock) {
        VStack {
            let layout = LayoutEngine([0, 1, 2]) { _ in Rectangle(.red) } placements: { _, at in
                (0..<3).map { Placement(Rect((Double($0) - at) * 30, 10, 20, 20)) }
            }
            .phase(phase.projectedValue)
            .input(.scroll(.horizontal, pointsPerUnit: 100))
            .snapTargets([0, 1, 2])
            .itemDrag(begins: begins)
            .onItemDragged { told.values.append("\($0.item) at \(Int($0.at.x)),\(Int($0.at.y))") }
            .motion(.eased(.milliseconds(200), .linear))
            if dismissing {
                layout.onItemDismissed(.down, beyond: 10) { told.values.append("\($0) dismissed") }
                    .width(100).height(40)
            } else {
                layout.width(100).height(40)
            }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
    frames(s, clock, until: 64)
    return try s.element(ofType: .layoutEngine)
}

/// A phase of two axes: how far a run is turned, and how large it stands.
private struct Orbit: LayoutPhase {
    var turn = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Orbit, Double>] { [\.turn, \.zoom] }
}

/// A layout of three views a hand moves across, a hundred points a unit, resting on 0 to 5, its run on `clock`: the
/// layout's element, once the room is told.
@MainActor
private func handLayout(_ s: Session, clock: TestClock, phase: State<Double>) throws -> MountedElement {
    s.start(clock: clock) {
        VStack {
            LayoutEngine([0, 1, 2]) { _ in Rectangle(.red) } placements: { _, at in
                (0..<3).map { Placement(Rect((Double($0) - at) * 50 + 40, 0, 20, 20)) }
            }
            .phase(phase.projectedValue)
            .input(.scroll(.horizontal, pointsPerUnit: 100))
            .snapTargets([0, 1, 2, 3, 4, 5])
            .motion(.eased(.milliseconds(300), .linear))
            .width(100).height(40)
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
    frames(s, clock, until: 64)
    return try s.element(ofType: .layoutEngine)
}

/// Display frames until `end`, sixteen milliseconds apart.
@MainActor
private func frames(_ s: Session, _ clock: TestClock, until end: Double) {
    while clock.now < end {
        clock.now += 16
        s.frame()
    }
}
