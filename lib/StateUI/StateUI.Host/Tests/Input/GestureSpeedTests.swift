// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A continuous gesture as every host tells it: where it stands since it began, and how fast it goes - its end as
/// fast as it lifted.
@MainActor
final class GestureSpeedTests: XCTestCase {
    /// A SPEED IS WHAT MOVED IN THE LAST TENTH OF A SECOND: over the time between its first and last move there, a
    /// frame at least; nought once nothing moved in it.
    func testASpeedIsWhatMovedInTheLastTenthOfASecond() {
        var reading = SpeedReading()
        reading.moved(Point(10, -5), at: 0)
        XCTAssertEqual(reading.speed(at: 0), Point(625, -312.5), "one move, over a frame")
        reading.moved(Point(10, 0), at: 16)
        reading.moved(Point(10, 0), at: 32)
        XCTAssertEqual(reading.speed(at: 32), Point(937.5, -156.25), "30 across in 32 milliseconds")
        XCTAssertEqual(reading.speed(at: 200), Point(0, 0), "nothing moved in the last tenth")
    }

    /// A PAN TELLS ITS TOTALS AND ITS SPEED: each report how far it came and how fast it goes, its end the totals it
    /// reached and the speed it lifted at, whatever the platform tells of the end.
    func testAPanTellsItsTotalsAndItsSpeed() throws {
        let (runtime, box, clock) = try running()
        let steps: [(Double, GesturePhase, Double)] = [(0, .began, 0), (16, .changed, 10), (32, .changed, 30),
                                                       (40, .ended, 0)]
        for (at, phase, x) in steps {
            clock.time = at
            box.hear(.drag(phase, x: x, y: 0), in: runtime)
        }
        runtime.pump.turn()

        XCTAssertEqual(pans.map(\.phase), [.began, .changed, .changed, .ended])
        XCTAssertEqual(pans.map(\.totalX), [0, 10, 30, 30])
        XCTAssertEqual(pans.map(\.velocityX), [0, 625, 1_875, 1_250])
    }

    /// A PINCH TELLS HOW FAST ITS SCALE CHANGES: the spread's steps read as a pan's moves are.
    func testAPinchTellsHowFastItsScaleChanges() throws {
        let (runtime, box, clock) = try running()
        for (at, phase, scale) in [(0.0, GesturePhase.began, 1.0), (16, .changed, 1.2), (32, .ended, 1)] {
            clock.time = at
            box.hear(.pinch(phase, scale: scale, at: Point(0.5, 0.5)), in: runtime)
        }
        runtime.pump.turn()

        XCTAssertEqual(pinches.map { ($0.velocity * 1_000).rounded() / 1_000 }, [0, 12.5, 6.25])
    }

    /// TWO FINGERS TURNING ARE TOLD FROM THEIR START: a view heard turning hears the platform's steps as the angle
    /// since they began and its speed; a turn whose beginning no platform told begins itself.
    func testTwoFingersTurningAreToldFromTheirStart() throws {
        let (runtime, box, clock) = try running()
        XCTAssertTrue(box.hearing.contains(.rotations), "a handler asks for two fingers turning")

        let steps: [(Double, GesturePhase, Double)] = [(0, .began, 0), (16, .changed, 10), (32, .changed, 5),
                                                       (48, .ended, 0), (60, .changed, 20)]
        for (at, phase, degrees) in steps {
            clock.time = at
            box.hear(.rotation(phase, degrees: degrees), in: runtime)
        }
        runtime.pump.turn()

        XCTAssertEqual(turns.map(\.phase), [.began, .changed, .changed, .ended, .began, .changed])
        XCTAssertEqual(turns.map(\.angle), [0, 10, 15, 15, 0, 20])
        XCTAssertEqual(turns.map(\.velocity), [0, 625, 468.75, 312.5, 0, 1_250])
    }

    /// A runtime of the page, its box, and the clock a test winds.
    private func running() throws -> (HostRuntime, MountedElement, WoundClock) {
        (pans, pinches, turns) = ([], [], [])
        stateUIUseApp(TurnedApplication())
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        return (runtime, try XCTUnwrap(runtime.tree.root?.first(id: .manual("box"))), clock)
    }
}

/// What the box heard, in order.
@MainActor private var pans: [PanUpdate] = []
@MainActor private var pinches: [PinchUpdate] = []
@MainActor private var turns: [RotationUpdate] = []

private struct TurnedApplication: Application {
    var body: some Scene {
        WindowGroup {
            Rectangle()
                .width(100)
                .height(100)
                .onPanUpdated { pans.append($0) }
                .onPinchUpdated { pinches.append($0) }
                .onRotationUpdated { turns.append($0) }
                .id("box")
        }
    }
}
