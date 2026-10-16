// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import StateUIFoundation
import XCTest

/// Two fingers over a layout a hand moves too, as every host hears them: the fingers take the hand from the run, and
/// the hand comes back only from a new press.
@MainActor
final class FingersHearingTests: XCTestCase {
    /// TWO FINGERS TAKE THE HAND: as they begin, the hand moving the run lets go where it is, still; what the
    /// platform tells of it after moves nothing; the fingers spread their own axis; a new press moves the run again.
    func testTwoFingersTakeTheHand() throws {
        let (runtime, clock) = running()
        let dial = try XCTUnwrap(runtime.tree.root?.first(type: .layoutEngine))
        XCTAssertTrue(dial.hearing.contains(.hand))
        XCTAssertTrue(dial.hearing.contains(.pinches))
        XCTAssertFalse(dial.hearing.contains(.rotations), "no rotation asked for")

        dial.hear(.hand(.began, moved: .zero, speed: nil), in: runtime)
        dial.hear(.hand(.changed, moved: Point(-40, 0), speed: nil), in: runtime)
        frames(runtime, clock, until: 32)
        XCTAssertEqual(handed.last?.turn ?? 0, 0.4, accuracy: 0.001, "the hand moves the run")

        dial.hear(.pinch(.began, scale: 1, at: Point(0.5, 0.5)), in: runtime)
        dial.hear(.pinch(.changed, scale: 2, at: Point(0.5, 0.5)), in: runtime)
        dial.hear(.hand(.changed, moved: Point(-60, 0), speed: nil), in: runtime)
        frames(runtime, clock, until: 1_000)
        XCTAssertEqual(handed.last?.zoom ?? 0, 2, accuracy: 0.001, "the fingers spread their axis")
        XCTAssertEqual(handed.last?.turn ?? 1, 0, accuracy: 0.001, "the run let go still, back onto its target")

        dial.hear(.pinch(.ended, scale: 1, at: Point(0.5, 0.5)), in: runtime)
        dial.hear(.hand(.ended, moved: .zero, speed: Point(-2_000, 0)), in: runtime)
        frames(runtime, clock, until: 2_000)
        XCTAssertEqual(handed.last?.turn ?? 1, 0, accuracy: 0.001, "the old hand's lift throws nothing")
        XCTAssertEqual(handed.last?.zoom ?? 0, 2, accuracy: 0.001)

        dial.hear(.hand(.began, moved: .zero, speed: nil), in: runtime)
        dial.hear(.hand(.changed, moved: Point(-80, 0), speed: nil), in: runtime)
        frames(runtime, clock, until: 2_032)
        XCTAssertEqual(handed.last?.turn ?? 0, 0.8, accuracy: 0.001, "a new press moves the run again")
    }

    /// A WHEEL TURNED AS A PINCH spreads the layout's magnification, and the frames let it go once the wheel stands
    /// still: the axis comes onto its target with no lift told.
    func testAWheelTurnedAsAPinchSpreadsTheMagnification() throws {
        let (runtime, clock) = running()
        let dial = try XCTUnwrap(runtime.tree.root?.first(type: .layoutEngine))

        for _ in 0..<8 { dial.hear(.wheelPinch(scale: WheelPinch.notch, at: Point(0.5, 0.5)), in: runtime) }
        frames(runtime, clock, until: 48)
        let zoom = handed.last?.zoom ?? 0
        XCTAssertGreaterThan(zoom, 2, "eight notches a tenth each: 2.14, past the largest target")
        XCTAssertLessThan(zoom, pow(WheelPinch.notch, 8), "giving less and less past it")

        frames(runtime, clock, until: 1_000)
        XCTAssertFalse(dial.wheelPinch.isOpen, "let go once still")
        XCTAssertEqual(handed.last?.zoom ?? 0, 2, accuracy: 0.001, "and resting on its target")
    }

    /// Display frames until `end`, sixteen milliseconds apart, the clock standing at each.
    private func frames(_ runtime: HostRuntime, _ clock: FingersClock, until end: Double) {
        while clock.time < end {
            clock.time += 16
            runtime.displayCycle.frame(now: clock.time)
            runtime.pump.turn()
        }
    }

    private func running() -> (HostRuntime, FingersClock) {
        handed = []
        stateUIUseApp(FingersApplication())
        let clock = FingersClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        try? XCTUnwrap(runtime.tree.root?.first(type: .layoutEngine))
            .reportFrame([0, 0, 300, 200, 0, 0, 0, 0], in: runtime)
        frames(runtime, clock, until: 16)
        return (runtime, clock)
    }
}

/// A phase a hand turns and two fingers spread.
private struct Dial: LayoutPhase {
    var turn = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Dial, Double>] { [\.turn, \.zoom] }
}

/// Where the run stood each time its arithmetic was handed the phase.
@MainActor private var handed: [Dial] = []

/// A clock the test winds.
@MainActor
private final class FingersClock: FrameClock {
    var time = 0.0
    lazy var now: () -> Double = { [unowned self] in time }
    var held = false
    var onFrame: ((Double) -> Void)?
}

private struct FingersPage: View {
    @State private var dial = Dial()

    var body: some View {
        LayoutEngine([0, 1, 2, 3, 4]) { Text("\($0)") } placements: { _, dial in
            handed.append(dial)
            return (0..<5).map { _ in Placement(Rect(0, 0, 10, 10)) }
        }
        .phase($dial)
        .input(.scroll(.horizontal, pointsPerUnit: 100), drives: \.turn)
        .input(.magnification(), drives: \.zoom)
        .snap(\.turn, to: [0, 1, 2, 3, 4])
        .snap(\.zoom, to: [1, 2])
        .motion(.eased(.milliseconds(200), .linear))
    }
}

private struct FingersApplication: Application {
    var body: some Scene { WindowGroup { FingersPage() } }
}
