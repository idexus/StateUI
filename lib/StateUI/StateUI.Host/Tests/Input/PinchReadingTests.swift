// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import StateUIFoundation
import XCTest

/// Two fingers over a layout, read alike on every host: a pinch and a rotation as one stream, and two pointers read
/// as both.
final class PinchReadingTests: XCTestCase {
    /// A PINCH AND A ROTATION ARE ONE STREAM: begun with the first, ended with the last, each move its own.
    func testAPinchAndARotationAreOneStream() {
        var reading = PinchReading()

        XCTAssertEqual(reading.pinch(.began, scale: 1, at: 0), [PinchReading.Report(.began)])
        XCTAssertEqual(reading.rotation(.began, degrees: 0, at: 0), [], "the second begins nothing")
        XCTAssertEqual(reading.pinch(.changed, scale: 2, at: 16).map(\.phase), [.changed])
        XCTAssertEqual(reading.pinch(.changed, scale: 2, at: 16).first?.scale ?? 0, 2, accuracy: 1e-9)
        XCTAssertEqual(reading.rotation(.changed, degrees: 30, at: 32), [PinchReading.Report(.changed, degrees: 30)])
        XCTAssertEqual(reading.pinch(.ended, scale: 1, at: 48), [], "one still under way")
        XCTAssertEqual(reading.rotation(.ended, degrees: 0, at: 48).map(\.phase), [.ended])
        XCTAssertFalse(reading.isOpen)
    }

    /// AS THEY LIFT, THE FINGERS' SPEED is read from their last tenth of a second: the scale's logarithm across, the
    /// degrees down, per second - nought where they stood still before lifting.
    func testTheSpeedAtTheLiftIsReadFromTheLastTenthOfASecond() {
        var reading = PinchReading()
        _ = reading.pinch(.began, scale: 1, at: 0)
        _ = reading.pinch(.changed, scale: exp(0.1), at: 0)
        _ = reading.rotation(.changed, degrees: 5, at: 50)
        _ = reading.pinch(.changed, scale: exp(0.1), at: 100)

        XCTAssertEqual(reading.pinch(.ended, scale: 1, at: 100), [], "the rotation still under way")
        let lift = reading.rotation(.ended, degrees: 0, at: 100)
        XCTAssertEqual(lift.first?.speed.x ?? 0, 2, accuracy: 1e-9, "0.2 of the logarithm in 100 ms")
        XCTAssertEqual(lift.first?.speed.y ?? 0, 50, accuracy: 1e-9, "5 degrees in 100 ms")

        _ = reading.pinch(.began, scale: 1, at: 1_000)
        _ = reading.pinch(.changed, scale: 1.5, at: 1_016)
        XCTAssertEqual(reading.pinch(.ended, scale: 1, at: 1_500).first?.speed, .zero, "stood still, then lifted")
    }

    /// A MOVE WITH NO BEGINNING HEARD BEGINS THE FINGERS, and a cancel of the last gesture cancels them.
    func testAMoveWithNoBeginningBeginsAndACancelCancels() {
        var reading = PinchReading()

        XCTAssertEqual(reading.rotation(.changed, degrees: 10, at: 0).map(\.phase), [.began, .changed])
        XCTAssertEqual(reading.rotation(.cancelled, degrees: 0, at: 16), [PinchReading.Report(.cancelled)])
    }

    /// TWO POINTERS ARE A PINCH AND A ROTATION: how far apart they stand, and which way the line between them turns,
    /// clockwise in a view whose y grows down - the short way round.
    func testTwoPointersAreAPinchAndARotation() throws {
        var fingers = TwoFingers()

        XCTAssertNil(fingers.moved(Point(0, 0), Point(10, 0)), "first standing")
        let spread = try XCTUnwrap(fingers.moved(Point(0, 0), Point(20, 0)))
        XCTAssertEqual(spread.scale, 2, accuracy: 1e-9)
        XCTAssertEqual(spread.degrees, 0, accuracy: 1e-9)

        let turned = try XCTUnwrap(fingers.moved(Point(0, 0), Point(0, 20)))
        XCTAssertEqual(turned.degrees, 90, accuracy: 1e-9, "right to down is clockwise")

        _ = fingers.moved(Point(0, 0), Point(-20, 1))
        let across = try XCTUnwrap(fingers.moved(Point(0, 0), Point(-20, -1)))
        XCTAssertEqual(across.degrees, 2 * atan2(1, 20) * 180 / .pi, accuracy: 1e-9, "the short way past 180")

        fingers.lifted()
        XCTAssertNil(fingers.moved(Point(0, 0), Point(40, 0)), "afresh after a lift")
    }

    /// A WHEEL TURNED AS A PINCH begins with its first turn, steps with each, and is let go once it has stood still
    /// as long as a wheel's pause - a wheel tells no lift.
    func testAWheelTurnedAsAPinchIsLetGoWhenItStandsStill() {
        var wheel = WheelPinch()
        let at = Point(0.5, 0.5)

        XCTAssertEqual(wheel.turned(1.1, at: at, now: 0), [.pinch(.began, scale: 1, at: at), .pinch(.changed, scale: 1.1, at: at)])
        XCTAssertEqual(wheel.turned(1.1, at: at, now: 30), [.pinch(.changed, scale: 1.1, at: at)])
        XCTAssertEqual(wheel.paced(now: 30 + HandReading.pause - 1), [], "still turning, near enough")
        XCTAssertEqual(wheel.paced(now: 30 + HandReading.pause), [.pinch(.ended, scale: 1, at: at)])
        XCTAssertFalse(wheel.isOpen)
        XCTAssertEqual(wheel.turned(1 / 1.1, at: at, now: 400).first, .pinch(.began, scale: 1, at: at), "afresh")
    }

    /// A ROTATION TOLD FROM WHERE IT BEGAN IS SAID AS ITS STEPS.
    func testARotationFromWhereItBeganIsSaidAsItsSteps() {
        var step = RotationStep()

        XCTAssertEqual(step.step(.began, degrees: 0), 0)
        XCTAssertEqual(step.step(.changed, degrees: 10), 10)
        XCTAssertEqual(step.step(.changed, degrees: 25), 15)
        XCTAssertEqual(step.step(.ended, degrees: 25), 0)
        XCTAssertEqual(step.step(.changed, degrees: 5), 5, "a new rotation from nought")
    }
}
