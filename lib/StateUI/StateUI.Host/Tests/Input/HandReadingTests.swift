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
    /// momentum, each step slower than the last. The third such step is the lift, at the speed the moves say; the
    /// momentum after it is swallowed, and a hand pushing again - the wheel half as fast again as the momentum at
    /// its slowest - is a new gesture.
    func testAWheelWhoseStepsFadeHasBeenLetGo() {
        var hand = HandReading()

        momentum(&hand)
        XCTAssertEqual(hand.notched(Point(-32, 0), at: 80), [.init(.changed, moved: Point(-32, 0))])

        let lift = hand.notched(Point(-28, 0), at: 96)
        XCTAssertEqual(lift.map(\.phase), [.ended], "the third step slower than the last")
        XCTAssertEqual(lift.last?.speed.x ?? 0, -228.0 / 96 * 1_000, accuracy: 0.001, "as fast as the moves went")
        XCTAssertFalse(hand.isWheeling)

        XCTAssertEqual(hand.notched(Point(-24, 0), at: 112), [], "the momentum after the lift, swallowed")
        XCTAssertEqual(hand.notched(Point(-24, 0), at: 128), [])
        XCTAssertEqual(hand.wheel(Point(-20, 0), at: 144, way: .horizontal).taken, true, "swallowed, not handed on")
        XCTAssertEqual(hand.notched(Point(-40, 0), at: 160), [], "a step alone pushes nothing")
        XCTAssertEqual(hand.notched(Point(-60, 0), at: 176), [])
        XCTAssertEqual(hand.notched(Point(-80, 0), at: 192).map(\.phase), [.began, .changed], "a hand pushing again")
    }

    /// A WHEEL'S EVEN NOTCHES NEVER FADE: a wheel turned notch by notch is let go only by a pause.
    func testAWheelsEvenNotchesNeverFade() {
        var hand = HandReading()

        for step in 0..<6 { _ = hand.notched(Point(0, -40), at: Double(step) * 50) }

        XCTAssertTrue(hand.isWheeling)
    }

    /// THE MOMENTUM ENDS WITH A PAUSE: a step after one is the next gesture, however small.
    func testTheMomentumEndsWithAPause() {
        var hand = HandReading()

        letGo(&hand)
        XCTAssertFalse(hand.isWheeling, "let go")

        XCTAssertEqual(hand.notched(Point(-4, 0), at: 400).map(\.phase), [.began, .changed])
    }

    /// THE MOMENTUM IS UNBROKEN: it steps every frame, a late one now and then, so a step after a gap of more than
    /// six frames is a hand that stopped it and moves again - the next gesture, however small.
    func testAGapInTheMomentumIsTheNextGesture() {
        var hand = HandReading()

        letGo(&hand)
        XCTAssertEqual(hand.notched(Point(-24, 0), at: 112), [], "the momentum, swallowed")
        XCTAssertEqual(hand.notched(Point(-2, 0), at: 178), [], "a frame or three late, still the momentum")

        XCTAssertEqual(hand.notched(Point(-2, 0), at: 290).map(\.phase), [.began, .changed])
    }

    /// A STEP AGAINST THE MOMENTUM is a hand that turned it back: the next gesture, however small.
    func testAStepAgainstTheMomentumIsTheNextGesture() {
        var hand = HandReading()

        letGo(&hand)

        XCTAssertEqual(hand.notched(Point(2, 0), at: 112).map(\.phase), [.began, .changed])
    }

    /// A TRACKPAD'S SWIPE ON A PAGE IS ONE GESTURE, its momentum swallowed to the last step: a frame drawn late
    /// doubles a step at the same pace, a step glued to the one before comes milliseconds after it, and the tail
    /// creeps a point a frame - none of them a hand. Safari's own events of one fast swipe.
    func testATrackpadSwipeOnAPageIsOneGesture() {
        var hand = HandReading()

        let reports = Self.swipe.flatMap { time, delta in hand.notched(Point(-delta, 0), at: time) }

        XCTAssertEqual(reports.filter { $0.phase == .began }.count, 1, "one gesture")
        XCTAssertEqual(reports.filter { $0.phase == .ended }.count, 1, "let go once")
        XCTAssertLessThan(reports.firstIndex { $0.phase == .ended } ?? .max, 20, "as the steps begin to fade")
    }

    /// A WHEEL THAT COMES UNEVENLY IS READ BY ITS PACE: steps a frame or two apart, one now and then three times
    /// the one before - one swipe, never a new gesture each time a step stands out. A fast swipe through
    /// Parallels to a layout in WinUI, as its tracker made it.
    func testAnUnevenWheelIsOneGesture() {
        var hand = HandReading()

        let reports = Self.uneven.flatMap { time, step in hand.notched(Point(step, 0), at: time) }

        XCTAssertEqual(reports.filter { $0.phase == .began }.count, 1, "one gesture")
    }

    /// Four steps of 40 points a frame, then slowing: 36, then the caller's.
    private func momentum(_ hand: inout HandReading) {
        for step in 0..<4 { _ = hand.notched(Point(-40, 0), at: Double(step) * 16) }
        _ = hand.notched(Point(-36, 0), at: 64)
    }

    /// The momentum slowing three steps in a row, let go at 96 milliseconds.
    private func letGo(_ hand: inout HandReading) {
        momentum(&hand)
        _ = hand.notched(Point(-32, 0), at: 80)
        _ = hand.notched(Point(-28, 0), at: 96)
    }

    /// A SLOW HAND MAKES NO MOMENTUM: steps of a point or less slow and quicken by chance, so a step counts toward a
    /// fade, as toward a push, only where it moves four points at least - a slow hand moves the run all the way,
    /// and a pause lets it go.
    func testASlowHandMakesNoMomentum() {
        var hand = HandReading()

        let reports = Self.drag.flatMap { time, step in hand.notched(Point(step, 0), at: time) }

        XCTAssertEqual(reports.filter { $0.phase == .ended }, [], "never let go while it moves")
        XCTAssertEqual(reports.filter { $0.phase == .changed }.count, Self.drag.count, "every step moved the run")
        XCTAssertTrue(hand.isWheeling)
    }

    /// A slow drag of two fingers over a layout on a Mac's trackpad, reaching Windows as a wheel and a layout in
    /// WinUI as the steps its tracker made of it (2026-10-15): when, in milliseconds, and how far, in points.
    private static let drag: [(Double, Double)] = [
        (0.0, 0.4), (32.3, 0.6), (51.9, 0.4), (67.9, 0.8), (82.6, 0.4), (98.8, 0.4), (115.6, 0.4), (132.5, 0.4),
        (148.6, 0.4), (165.1, 0.4), (181.9, 0.4), (198.8, 0.4), (215.4, 0.4), (231.5, 0.4), (265.1, 0.4),
        (281.9, 0.6), (298.4, 0.6), (314.2, 0.6), (330.3, 0.4), (347.7, 0.4), (364.9, 0.4), (381.4, 0.4),
        (398.0, 0.4), (413.9, 0.4), (430.1, 0.4), (443.9, 0.4), (459.8, 0.4), (493.0, 0.8), (509.7, 0.4),
        (526.5, 0.4), (543.0, 0.4), (559.9, 0.4), (576.4, 0.4), (593.0, 0.4), (626.9, 0.4), (643.1, 0.8),
        (676.6, 0.4), (693.3, 0.4), (746.2, 1.4), (759.8, 0.6),
    ]

    /// A fast swipe of two fingers on a Mac's trackpad, reaching Windows through Parallels as a wheel and a layout
    /// in WinUI as the steps its tracker made of it, slowing to its tail (2026-10-15): milliseconds, points.
    private static let uneven: [(Double, Double)] = [
        (0.0, 8.8), (17.0, 11.6), (50.8, 16.8), (71.0, 40.4), (97.3, 27.8), (117.2, 84.8), (133.4, 28.8),
        (150.6, 27.6), (181.4, 26.2), (203.7, 48.2), (218.0, 22), (234.6, 21), (251.1, 20), (267.4, 19.2),
        (301.0, 18.4), (321.5, 17.4), (334.4, 31.8), (350.3, 14.4), (380.8, 13.6), (400.8, 24.6), (431.9, 21.2),
        (464.7, 18), (483.7, 8.2), (500.3, 7.4), (518.5, 7), (552.0, 6.4), (572.6, 11), (585.0, 4.8), (600.4, 4.4),
        (618.3, 4), (651.0, 3.8), (670.6, 6.6), (698.3, 2.8), (717.2, 5), (733.9, 2.2), (750.7, 2), (781.3, 1.8),
        (800.6, 3.2), (817.2, 1.4),
    ]

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

    /// A WHEEL TURNED NOTCH BY NOTCH STEPS THE RUN, a step a notch, along the layout's axis alone; a fine wheel's
    /// parts of a notch add up to whole ones, and a notch across the axis is left to whatever holds the layout.
    func testAWheelsNotchesAreStepsAlongTheAxis() {
        var hand = HandReading()

        XCTAssertEqual(hand.notches(Point(-1, 0), way: .horizontal).steps, Point(-1, 0))
        XCTAssertEqual(hand.notches(Point(-3, 0), way: .horizontal).steps, Point(-3, 0), "as many as it turned")

        XCTAssertEqual(hand.notches(Point(0.5, 0), way: .horizontal).steps, nil, "half a notch: none yet")
        let whole = hand.notches(Point(0.75, 0), way: .horizontal)
        XCTAssertEqual(whole.taken, true)
        XCTAssertEqual(whole.steps, Point(1, 0), "the parts make one, the rest kept")
        XCTAssertEqual(hand.notches(Point(0.75, 0), way: .horizontal).steps, Point(1, 0))

        let across = hand.notches(Point(0, -1), way: .horizontal)
        XCTAssertEqual(across.taken, false, "down, over a run moved across")
        XCTAssertEqual(hand.notches(Point(0, -1), way: .vertical).steps, Point(0, -1))
        XCTAssertEqual(hand.notches(Point(-1, 0.5), way: .everyWay).steps, Point(-1, 0), "a pan's: each way its own")
        XCTAssertEqual(hand.notches(Point(0, 0.5), way: .everyWay).steps, Point(0, 1))
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

        XCTAssertTrue(hand.hand(.began, moved: .zero, speed: nil, at: 0, way: .horizontal).taken, "not yet decided")
        let first = hand.hand(.changed, moved: Point(-10, 2), speed: nil, at: 16, way: .horizontal)
        XCTAssertEqual(first.reports, [.init(.began), .init(.changed, moved: Point(-10, 2))])
        XCTAssertTrue(hand.hand(.ended, moved: .zero, speed: Point(-300, 0), at: 32, way: .horizontal).taken)
        XCTAssertEqual(hand.claimed, true, "kept past the lift, for what the platform tells after it")

        _ = hand.hand(.began, moved: .zero, speed: nil, at: 100, way: .horizontal)
        let across = hand.hand(.changed, moved: Point(2, -10), speed: nil, at: 116, way: .horizontal)
        XCTAssertFalse(across.taken)
        XCTAssertEqual(across.reports, [])
        XCTAssertFalse(hand.hand(.changed, moved: Point(-30, 0), speed: nil, at: 132, way: .horizontal).taken,
                       "a gesture left stays left")
        XCTAssertFalse(hand.hand(.ended, moved: .zero, speed: nil, at: 148, way: .horizontal).taken)
    }

    /// A LAYOUT CLAIMS THE HAND MOVING MORE ALONG ITS AXIS THAN ACROSS IT: the rest is for whatever holds it.
    func testALayoutClaimsTheHandMovingAlongItsAxis() {
        XCTAssertTrue(HandReading.claims(Point(-10, 4), way: .horizontal))
        XCTAssertFalse(HandReading.claims(Point(-4, 10), way: .horizontal))
        XCTAssertTrue(HandReading.claims(Point(2, -9), way: .vertical))
        XCTAssertFalse(HandReading.claims(Point(0, 0), way: .vertical), "no move is no claim yet")
        XCTAssertTrue(HandReading.claims(Point(-4, 10), way: .everyWay), "a pan takes every way")
        XCTAssertFalse(HandReading.claims(Point(0, 0), way: .everyWay))
    }
    /// A FIRST MOVE ACROSS THE AXIS HOLDS THE VIEW UNDER THE PRESS where the layout's views are taken so: from where
    /// it went down, the view's to its lift, whichever way it goes after.
    func testAFirstMoveAcrossHoldsTheViewUnderThePress() {
        var hand = HandReading()
        func heard(_ phase: GesturePhase, _ moved: Point, at time: Double, speed: Point? = nil, point: Point? = nil)
            -> (taken: Bool, reports: [HandReading.Report])
        {
            hand.hand(phase, moved: moved, speed: speed, at: time, way: .horizontal, point: point, items: .across)
        }

        XCTAssertEqual(heard(.began, .zero, at: 0, point: Point(50, 60)).reports, [])
        let first = heard(.changed, Point(2, 12), at: 16)
        XCTAssertTrue(first.taken)
        XCTAssertEqual(first.reports, [
            .init(.began, item: true, at: Point(50, 60)), .init(.changed, moved: Point(2, 12), item: true, at: Point(52, 72)),
        ])
        XCTAssertEqual(heard(.changed, Point(30, 0), at: 32).reports.last?.at, Point(82, 72), "along it after, still the view's")
        let lift = heard(.ended, .zero, at: 48, speed: Point(0, 600)).reports
        XCTAssertEqual(lift, [.init(.ended, speed: Point(0, 600), item: true, at: Point(82, 72))])
        XCTAssertFalse(hand.holdsItem)
    }

    /// A FIRST MOVE ALONG THE AXIS IS THE RUN'S, views taken or not; across it, with no view taken so, the page's.
    func testAFirstMoveAlongIsTheRunsAndAcrossThePagesWithNoViewTaken() {
        var hand = HandReading()

        _ = hand.hand(.began, moved: .zero, speed: nil, at: 0, way: .horizontal, point: Point(50, 60), items: .across)
        let along = hand.hand(.changed, moved: Point(12, 2), speed: nil, at: 16, way: .horizontal)
        XCTAssertEqual(along.reports, [.init(.began), .init(.changed, moved: Point(12, 2))])

        _ = hand.hand(.ended, moved: .zero, speed: Point(0, 0), at: 32, way: .horizontal)
        _ = hand.hand(.began, moved: .zero, speed: nil, at: 40, way: .horizontal, point: Point(50, 60))
        XCTAssertFalse(hand.hand(.changed, moved: Point(2, 12), speed: nil, at: 56, way: .horizontal).taken)
    }

    /// A PRESS STANDING STILL A HOLD HOLDS THE VIEW UNDER IT, where the layout's views are taken so - found by the
    /// frames, since nothing moves - and a move before it is the run's.
    func testAPressStandingStillAHoldHoldsTheViewUnderIt() {
        var hand = HandReading()

        _ = hand.hand(.began, moved: .zero, speed: nil, at: 0, way: .horizontal, point: Point(40, 40), items: .held)
        XCTAssertTrue(hand.wantsFrames, "the frames find the hold")
        XCTAssertEqual(hand.paced(at: 480), [])
        XCTAssertEqual(hand.paced(at: 500), [.init(.began, item: true, at: Point(40, 40))])
        XCTAssertEqual(hand.hand(.changed, moved: Point(0, 30), speed: nil, at: 520, way: .horizontal).reports,
                       [.init(.changed, moved: Point(0, 30), item: true, at: Point(40, 70))], "then any way")

        _ = hand.hand(.ended, moved: .zero, speed: nil, at: 540, way: .horizontal)
        _ = hand.hand(.began, moved: .zero, speed: nil, at: 600, way: .horizontal, point: Point(40, 40), items: .held)
        XCTAssertEqual(hand.hand(.changed, moved: Point(20, 0), speed: nil, at: 700, way: .horizontal).reports,
                       [.init(.began), .init(.changed, moved: Point(20, 0))], "moved before the hold: the run's")
        XCTAssertEqual(hand.paced(at: 1_200), [], "and no hold after")
    }

    /// A HELD VIEW STANDING STILL IS TOLD AGAIN EACH HOLD, how long it has stood; a move starts the count again.
    func testAHeldViewStandingStillIsToldEachHold() {
        var hand = HandReading()

        _ = hand.hand(.began, moved: .zero, speed: nil, at: 0, way: .horizontal, point: Point(40, 40), items: .held)
        _ = hand.paced(at: 500)
        XCTAssertEqual(hand.paced(at: 900), [])
        XCTAssertEqual(hand.paced(at: 1_000), [.init(.changed, item: true, at: Point(40, 40), still: 500)])
        XCTAssertEqual(hand.paced(at: 1_200), [])
        XCTAssertEqual(hand.paced(at: 1_500), [.init(.changed, item: true, at: Point(40, 40), still: 1_000)])

        _ = hand.hand(.changed, moved: Point(5, 0), speed: nil, at: 1_600, way: .horizontal)
        XCTAssertEqual(hand.paced(at: 2_000), [])
        XCTAssertEqual(hand.paced(at: 2_100), [.init(.changed, item: true, at: Point(45, 40), still: 500)])
    }
}
