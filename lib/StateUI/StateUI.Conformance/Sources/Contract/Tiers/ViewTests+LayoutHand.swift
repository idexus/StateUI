// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension ViewTests {
    /// What a hand does to a number its view's interaction names, on a motion layout: it rests on a snap, a throw
    /// carries it on, a wheel's notch steps it, a program's write takes it, a hand across its way leaves it, and two
    /// fingers spread and turn it.
    @MainActor
    static var layoutUnderTheHand: [ConformanceCase] {
        [
            ConformanceCase("MotionLayout.theHandMovesTheRunAndRestsItOnTheNearestTarget", proves: [
                Covered(ViewContract.interaction, on: MotionLayoutContract.self),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try HandLayouts.hand(s, clock: clock, phase: phase)

                // 140 points to the left is 1.4 targets on: let go still, it rests on the nearest.
                try s.perform(.sweep(by: Point(-140, 0), speed: .zero), on: layout)
                s.frames(of: clock, until: 1_600)

                s.expect(phase.wrappedValue, 1, "the target nearest where the hand let it go")
            },
            ConformanceCase("MotionLayout.aThrowGoesOnToTheTargetNearestWhereItWouldEnd", proves: [
                Covered(ViewContract.interaction, on: MotionLayoutContract.self),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try HandLayouts.hand(s, clock: clock, phase: phase)

                // Let go at 2,250 points a second, 22.5 targets a second, the throw carries it three targets on.
                try s.perform(.sweep(by: Point(-10, 0), speed: Point(-2_250, 0)), on: layout)
                s.frames(of: clock, until: 1_600)

                s.expect(phase.wrappedValue, 3, "not the nearest to where the hand let go, but to where the throw ends")
            },
            ConformanceCase("MotionLayout.aThrowGoesOnAsThePhasesJourney", proves: [
                Covered(ViewContract.interaction, on: MotionLayoutContract.self),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try HandLayouts.hand(s, clock: clock, phase: phase)
                let journey = phase.projectedValue.journey

                try s.perform(.sweep(by: Point(-10, 0), speed: Point(-2_250, 0)), on: layout)
                // Each frame read as the host walks it: on its way to the target named already, going on.
                var (fastest, onItsWay) = (0.0, false)
                while clock.now < 1_600 {
                    clock.now += 16
                    s.frame()
                    guard let sample = journey.sample else { continue }

                    fastest = max(fastest, sample.velocity)
                    if phase.wrappedValue == 3, sample.value > 0.1, sample.value < 3 { onItsWay = true }
                }
                s.expect(fastest > 0, true, "going on, as the host walks the phase")
                s.expect(onItsWay, true, "on its way to the target it named")
                s.expect(journey.sample?.value, 3, "on its target")
                s.expect(journey.sample?.velocity, 0, "at rest")
            },
            ConformanceCase("MotionLayout.aWheelsNotchStepsTheRunToTheNextTarget", proves: [
                Covered(ViewContract.interaction, on: MotionLayoutContract.self),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try HandLayouts.hand(s, clock: clock, phase: phase)

                // A notch is a step, however far a target stands: one on, then two more.
                try s.perform(.notch(by: Point(-1, 0)), on: layout)
                s.frames(of: clock, until: 800)
                s.expect(phase.wrappedValue, 1, "the next target")

                try s.perform(.notch(by: Point(-2, 0)), on: layout)
                s.frames(of: clock, until: 1_600)
                s.expect(phase.wrappedValue, 3, "a target a notch")
            },
            ConformanceCase("MotionLayout.aProgramsWriteTakesTheRunFromTheHand", proves: [
                Covered(ViewContract.interaction, on: MotionLayoutContract.self),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try HandLayouts.hand(s, clock: clock, phase: phase)

                // The hand takes the run and holds it 0.4 targets on, bound for the first.
                try s.perform(.pressDown(at: Point(60, 10)), on: layout)
                try s.perform(.drag(to: Point(20, 10)), on: layout)
                s.frames(of: clock, until: clock.now + 48)
                s.expect(phase.wrappedValue, 0, "under the hand, bound for the nearest target")

                // The program sends it to the fifth: the hand's gesture ends there, whatever it says after.
                phase.wrappedValue = 4
                s.frames(of: clock, until: clock.now + 48)
                try s.perform(.drag(to: Point(90, 10)), on: layout)
                s.frames(of: clock, until: clock.now + 48)
                try s.perform(.lift(at: Point(90, 10)), on: layout)
                s.frames(of: clock, until: clock.now + 1_600)

                s.expect(phase.wrappedValue, 4, "where the program sent it")
                s.expect(phase.projectedValue.journey.sample?.value, 4, "and standing there")
            },
            ConformanceCase("MotionLayout.aHandAcrossItsAxisLeavesTheRun", proves: [
                Covered(ViewContract.interaction, on: MotionLayoutContract.self),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try HandLayouts.hand(s, clock: clock, phase: phase)

                try s.perform(.sweep(by: Point(0, -140), speed: Point(0, -600)), on: layout)
                s.frames(of: clock, until: 1_600)

                s.expect(phase.wrappedValue, 0, "a hand moving down is not the run's, which moves across")
            },
            ConformanceCase("MotionLayout.aPanMovesTheRunEveryWayAndRestsOnTheNearestSquare", proves: [
                Covered(ViewContract.interaction, on: MotionLayoutContract.self),
            ]) { s in
                let (clock, square) = (TestClock(), State(wrappedValue: HandLayouts.Square()))
                let layout = try HandLayouts.pan(s, clock: clock, square: square)

                // 140 points to the left and 60 up are 1.4 squares on across and 0.6 down: let go still, the nearest.
                try s.perform(.sweep(by: Point(-140, -60), speed: .zero), on: layout)
                s.frames(of: clock, until: clock.now + 1_600)
                s.expect(square.wrappedValue, HandLayouts.Square(x: 1, y: 1), "both axes on the square nearest")
            },
            ConformanceCase("MotionLayout.twoFingersSpreadTheMagnification", proves: [
                Covered(ViewContract.interaction, on: MotionLayoutContract.self),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 1.0))
                let layout = try HandLayouts.fingers(s, clock: clock, phase: phase, input: .magnification)

                try s.perform(.pinch(scale: 2, at: Point(0.5, 0.5)), on: layout)
                s.frames(of: clock, until: clock.now + 1_000)
                s.expect(phase.wrappedValue, 2, "spread to twice their distance: twice the size")

                // To the ends, so a lift at the driver's speed rests where a still one does.
                try s.perform(.pinch(scale: 0.25, at: Point(0.5, 0.5)), on: layout)
                s.frames(of: clock, until: clock.now + 1_000)
                s.expect(phase.wrappedValue, 0.5, "and pinched in to a quarter: the smallest")
            },
            ConformanceCase("MotionLayout.twoFingersTurnTheRotation", proves: [
                Covered(ViewContract.interaction, on: MotionLayoutContract.self),
            ]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 1.0))
                let layout = try HandLayouts.fingers(s, clock: clock, phase: phase, input: .rotation(degreesPerUnit: 90))

                try s.perform(.rotate(degrees: 90, at: Point(0.5, 0.5)), on: layout)
                s.frames(of: clock, until: clock.now + 1_000)
                s.expect(phase.wrappedValue, 2, "a quarter turn clockwise: a unit on")

                try s.perform(.rotate(degrees: -180, at: Point(0.5, 0.5)), on: layout)
                s.frames(of: clock, until: clock.now + 1_000)
                s.expect(phase.wrappedValue, 0.5, "and back the other way, to the lowest")
            },
        ]
    }
}
