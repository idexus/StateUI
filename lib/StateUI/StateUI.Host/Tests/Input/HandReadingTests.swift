// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// The hand over a layout engine, read alike on every host: a press dragged or a trackpad's fingers reported as they
/// move, a wheel's notches with no lift, and the speed at the lift where the platform tells none.
final class HandReadingTests: XCTestCase {
    /// A HAND IS REPORTED AS IT MOVES: its beginning, each move, and its lift with the speed the platform told.
    func testAHandIsReportedAsItMoves() {
        var hand = HandReading()

        XCTAssertEqual(hand.began(at: 0), [.init(.began)])
        XCTAssertEqual(hand.moved(Point(-10, 0), at: 16), [.init(.changed, moved: Point(-10, 0))])
        XCTAssertEqual(hand.lifted(at: 32, speed: Point(-600, 0)), [.init(.ended, speed: Point(-600, 0))])
    }

    /// WHERE THE PLATFORM TELLS NO SPEED, THE LAST MOVES SAY IT: how far the hand went in its last tenth of a
    /// second, a second's worth.
    func testWithNoSpeedToldTheLastMovesSayIt() {
        var hand = HandReading()

        _ = hand.began(at: 0)
        _ = hand.moved(Point(-100, 0), at: 10)
        _ = hand.moved(Point(-10, 0), at: 200)
        _ = hand.moved(Point(-10, 0), at: 220)
        let lift = hand.lifted(at: 240, speed: nil)

        XCTAssertEqual(lift.last?.speed.x ?? 0, -500, accuracy: 0.001, "20 points in the last 40 ms")
    }

    /// A HAND HELD STILL BEFORE IT LIFTS THROWS NOTHING: no move in the last tenth of a second is no speed.
    func testAHandHeldStillThrowsNothing() {
        var hand = HandReading()

        _ = hand.began(at: 0)
        _ = hand.moved(Point(-50, 0), at: 10)

        XCTAssertEqual(hand.lifted(at: 400, speed: nil).last?.speed, Point(0, 0))
    }

    /// A WHEEL BEGINS AT ITS FIRST NOTCH AND ENDS AFTER A PAUSE, as no lift is told: a notch while open is a move.
    func testAWheelBeginsAtItsFirstNotchAndEndsAfterAPause() {
        var hand = HandReading()

        XCTAssertEqual(hand.notched(Point(0, -40), at: 0), [.init(.began), .init(.changed, moved: Point(0, -40))])
        XCTAssertEqual(hand.notched(Point(0, -40), at: 50), [.init(.changed, moved: Point(0, -40))])
        XCTAssertTrue(hand.isWheeling)

        XCTAssertEqual(hand.paced(at: 120), [], "a pause too short to end it")
        XCTAssertEqual(hand.paced(at: 220), [.init(.ended)], "the wheel let go, with no throw")
        XCTAssertFalse(hand.isWheeling)
        XCTAssertEqual(hand.paced(at: 400), [], "and ended once")
    }

    /// A WHEEL WHOSE STEPS FADE HAS BEEN LET GO: a trackpad that tells no lift goes on with the system's
    /// momentum, each step smaller than the last. The third such step is the lift, at the speed the moves say; the
    /// momentum after it is swallowed, and a step that grows again is a new gesture.
    func testAWheelWhoseStepsFadeHasBeenLetGo() {
        var hand = HandReading()

        _ = hand.notched(Point(-30, 0), at: 0)
        _ = hand.notched(Point(-40, 0), at: 16)
        XCTAssertEqual(hand.notched(Point(-36, 0), at: 32), [.init(.changed, moved: Point(-36, 0))])
        XCTAssertEqual(hand.notched(Point(-32, 0), at: 48), [.init(.changed, moved: Point(-32, 0))])

        let lift = hand.notched(Point(-28, 0), at: 64)
        XCTAssertEqual(lift.map(\.phase), [.ended], "the third step smaller than the last")
        XCTAssertEqual(lift.last?.speed.x ?? 0, -138.0 / 64 * 1_000, accuracy: 0.001, "as fast as the moves went")
        XCTAssertFalse(hand.isWheeling)

        XCTAssertEqual(hand.notched(Point(-24, 0), at: 80), [], "the momentum after the lift, swallowed")
        XCTAssertEqual(hand.notched(Point(-24, 0), at: 96), [])
        XCTAssertEqual(hand.wheel(Point(-20, 0), at: 112, along: .horizontal).taken, true,
                       "swallowed, not handed on")
        XCTAssertEqual(hand.notched(Point(-40, 0), at: 128).map(\.phase), [.began, .changed],
                       "a step that grows is a new gesture")
    }

    /// A WHEEL'S EVEN NOTCHES NEVER FADE: a wheel turned notch by notch is let go only by a pause.
    func testAWheelsEvenNotchesNeverFade() {
        var hand = HandReading()

        for step in 0..<6 { _ = hand.notched(Point(0, -40), at: Double(step) * 50) }

        XCTAssertTrue(hand.isWheeling)
    }

    /// THE MOMENTUM IS UNBROKEN: it steps every frame, a late one now and then, so a step after a gap of more than
    /// six frames is a hand that stopped it and moves again - the next gesture, however small.
    func testAGapInTheMomentumIsTheNextGesture() {
        var hand = HandReading()

        for (step, size) in [40.0, 36, 32, 28].enumerated() { _ = hand.notched(Point(-size, 0), at: Double(step) * 16) }
        XCTAssertEqual(hand.notched(Point(-24, 0), at: 64), [], "the momentum, swallowed")
        XCTAssertEqual(hand.notched(Point(-2, 0), at: 130), [], "a frame or three late, still the momentum")

        XCTAssertEqual(hand.notched(Point(-2, 0), at: 240).map(\.phase), [.began, .changed])
    }

    /// A STEP AGAINST THE MOMENTUM is a hand that turned it back: the next gesture, however small.
    func testAStepAgainstTheMomentumIsTheNextGesture() {
        var hand = HandReading()

        for (step, size) in [40.0, 36, 32, 28].enumerated() { _ = hand.notched(Point(-size, 0), at: Double(step) * 16) }

        XCTAssertEqual(hand.notched(Point(2, 0), at: 64).map(\.phase), [.began, .changed])
    }

    /// A TRACKPAD'S SWIPE ON A PAGE IS ONE GESTURE, its momentum swallowed to the last step: a frame drawn late
    /// doubles a step at the same pace, a step glued to the one before comes milliseconds after it, and the tail
    /// creeps a point a frame - none of them a hand. Safari's own events of one fast swipe.
    func testATrackpadSwipeOnAPageIsOneGesture() {
        var hand = HandReading()

        let reports = Self.swipe.flatMap { time, delta in hand.notched(Point(-delta, 0), at: time) }

        XCTAssertEqual(reports.filter { $0.phase == .began }.count, 1, "one gesture")
        XCTAssertEqual(reports.filter { $0.phase == .ended }.count, 1, "let go once")
        XCTAssertLessThan(reports.firstIndex { $0.phase == .ended } ?? .max, 16, "as the steps begin to fade")
    }

    /// One fast swipe of two fingers over a page in Safari on a Mac's trackpad, its momentum after it, as the page
    /// heard it (2026-10-15): when, in milliseconds, and how far, `deltaX`.
    private static let swipe: [(Double, Double)] = [
        (0.0, 1), (16.6, 5), (34.0, 10), (50.1, 21), (67.3, 40), (83.8, 66), (100.0, 92), (116.6, 112), (133.8, 144),
        (150.4, 150), (167.1, 148), (183.7, 141), (200.4, 134), (217.0, 126), (233.7, 117), (250.4, 111),
        (266.7, 106), (283.7, 103), (300.5, 97), (317.0, 93), (333.7, 89), (349.7, 84), (367.1, 79), (383.8, 74),
        (400.5, 70), (417.5, 64), (433.9, 60), (450.4, 57), (467.2, 53), (483.8, 49), (500.4, 45), (517.7, 41),
        (533.9, 39), (550.2, 35), (567.8, 33), (583.8, 30), (599.9, 28), (617.1, 26), (633.8, 22), (650.4, 21),
        (667.7, 19), (683.8, 17), (700.4, 16), (717.5, 14), (734.6, 13), (750.0, 12), (771.2, 11), (783.9, 10),
        (800.4, 9), (833.5, 17), (850.4, 7), (867.0, 7), (885.5, 6), (900.4, 6), (916.2, 5), (933.8, 5), (950.1, 5),
        (966.9, 4), (983.8, 4), (1000.0, 4), (1017.0, 3), (1033.8, 3), (1050.5, 3), (1066.8, 3), (1084.2, 2),
        (1099.7, 2), (1117.1, 2), (1133.8, 2), (1150.1, 1), (1166.3, 1), (1183.7, 1), (1199.9, 1), (1216.9, 1),
        (1250.4, 1), (1267.1, 1), (1283.5, 1),
    ]

    /// THE MOMENTUM ENDS WITH A PAUSE: a step after one is the next gesture, however small.
    func testTheMomentumEndsWithAPause() {
        var hand = HandReading()

        for (step, size) in [40.0, 36, 32, 28].enumerated() { _ = hand.notched(Point(-size, 0), at: Double(step) * 16) }
        XCTAssertFalse(hand.isWheeling, "let go")

        XCTAssertEqual(hand.notched(Point(-4, 0), at: 400).map(\.phase), [.began, .changed])
    }

    /// A HAND BEGINNING WHILE A WHEEL IS OPEN ENDS THE WHEEL FIRST: one gesture at a time.
    func testAHandBeginningEndsAnOpenWheel() {
        var hand = HandReading()

        _ = hand.notched(Point(-40, 0), at: 0)

        XCTAssertEqual(hand.began(at: 20), [.init(.ended), .init(.began)])
    }

    /// A GESTURE IS THE LAYOUT'S BY ITS FIRST MOVE: along the axis, it begins there and goes on; across, every step
    /// of it is left - its lift too, and what comes after the lift.
    func testAGestureIsTheLayoutsByItsFirstMove() {
        var hand = HandReading()

        XCTAssertTrue(hand.hand(.began, moved: .zero, speed: nil, at: 0, along: .horizontal).taken, "not yet decided")
        let first = hand.hand(.changed, moved: Point(-10, 2), speed: nil, at: 16, along: .horizontal)
        XCTAssertEqual(first.reports, [.init(.began), .init(.changed, moved: Point(-10, 2))])
        XCTAssertTrue(hand.hand(.ended, moved: .zero, speed: Point(-300, 0), at: 32, along: .horizontal).taken)
        XCTAssertEqual(hand.claimed, true, "kept past the lift, for what the platform tells after it")

        _ = hand.hand(.began, moved: .zero, speed: nil, at: 100, along: .horizontal)
        let across = hand.hand(.changed, moved: Point(2, -10), speed: nil, at: 116, along: .horizontal)
        XCTAssertFalse(across.taken)
        XCTAssertEqual(across.reports, [])
        XCTAssertFalse(hand.hand(.changed, moved: Point(-30, 0), speed: nil, at: 132, along: .horizontal).taken,
                       "a gesture left stays left")
        XCTAssertFalse(hand.hand(.ended, moved: .zero, speed: nil, at: 148, along: .horizontal).taken)
    }

    /// A LAYOUT CLAIMS THE HAND MOVING MORE ALONG ITS AXIS THAN ACROSS IT: the rest is for whatever holds it.
    func testALayoutClaimsTheHandMovingAlongItsAxis() {
        XCTAssertTrue(HandReading.claims(Point(-10, 4), along: .horizontal))
        XCTAssertFalse(HandReading.claims(Point(-4, 10), along: .horizontal))
        XCTAssertTrue(HandReading.claims(Point(2, -9), along: .vertical))
        XCTAssertFalse(HandReading.claims(Point(0, 0), along: .vertical), "no move is no claim yet")
    }
}
