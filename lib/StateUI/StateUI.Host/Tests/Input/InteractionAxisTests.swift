// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// One number a hand moves, as its arithmetic answers with no runtime: where it may rest - a list, every multiple
/// of a step, anywhere in its range - which of two snaps as near it takes, and how a throw flies.
final class InteractionAxisTests: XCTestCase {
    private let cubicOut = Motion.eased(.milliseconds(400))

    /// A number moved a point a unit by a hand across.
    private func axis(
        low: Double = -.infinity, high: Double = .infinity, snaps: HostInteractionSnaps? = nil,
        periodic: Bool = false, input: HostInteractionInput = .translation(.horizontal, unit: .points(1), swipes: false),
        release: InteractionRelease = .projected(.eased(.milliseconds(400)))
    ) -> InteractionAxis {
        InteractionAxis(HostInteractionValue(
            state: 1, lane: 0, input: input, low: low, high: high, snaps: snaps, periodic: periodic, release: release))
    }

    /// EVERY MULTIPLE OF A STEP IS WORKED OUT, never listed: with no range the number rests on the multiple
    /// nearest, however far from nought, steps a notch to the next, and the next is the next.
    func testEveryMultipleOfAStepIsWorkedOut() {
        let stepped = axis(snaps: .every(0.5))

        XCTAssertEqual(stepped.nearest(1_000_000.2), 1_000_000, accuracy: 1e-6)
        XCTAssertEqual(stepped.nearest(-7.3), -7.5, accuracy: 1e-9)
        XCTAssertEqual(stepped.resting(at: 0.26), 0.5)
        XCTAssertEqual(stepped.stepped(2, by: 3), 3.5)
        XCTAssertEqual(stepped.stepped(2.1, by: -1), 1.5)
        XCTAssertTrue(stepped.next(from: 2.1, to: 2.5))
        XCTAssertFalse(stepped.next(from: 1.9, to: 2.5), "2 stands between them")
    }

    /// A LIST WITH NO RANGE STANDS AS WRITTEN: its snaps and no ends beside them.
    func testAListWithNoRangeStandsAsWritten() {
        let listed = axis(snaps: .at([1, 2]))

        XCTAssertEqual(listed.resting(at: 40), 2)
        XCTAssertEqual(listed.resting(at: -40), 1)
        XCTAssertEqual(listed.stepped(1, by: 5), 2, "held to the last")
    }

    /// OF TWO SNAPS AS NEAR, THE ONE THE HAND WAS GOING TOWARD; the lower for a hand standing still.
    func testOfTwoSnapsAsNearTheHandsWayChooses() {
        let even = axis(low: 0, high: 2, snaps: .at([0, 1, 2]))

        XCTAssertEqual(even.resting(at: 0.5), 0, "still: the lower")
        XCTAssertEqual(even.resting(at: 0.5, toward: 1), 1, "going on: the one ahead")
        XCTAssertEqual(even.resting(at: 1.5, toward: -1), 1, "going back: the one behind")
        XCTAssertEqual(even.resting(at: 0.6, toward: -1), 1, "nearer one way: the hand's way chooses nothing")
    }

    /// WITH NO SNAPS A NUMBER RESTS ANYWHERE IN ITS RANGE, and one that comes round, or has no end, anywhere.
    func testWithNoSnapsItRestsAnywhereInItsRange() {
        XCTAssertEqual(axis(low: 0, high: 3).resting(at: 3.4), 3)
        XCTAssertEqual(axis(low: 0, high: 3).resting(at: 1.37), 1.37)
        XCTAssertEqual(axis(low: 0, high: 3, periodic: true).resting(at: 3.4), 3.4)
        XCTAssertEqual(axis().resting(at: -1_234.5), -1_234.5, "no range: no end")
    }

    /// A MAGNIFICATION IS WORKED ON BY ITS LOGARITHM: of 1 and 4, 2 is as near either, and 2.1 nearer 4.
    func testAMagnificationIsNearestByItsLogarithm() {
        let zoom = axis(low: 1, high: 4, snaps: .at([1, 4]), input: .magnification)

        XCTAssertEqual(zoom.resting(at: 1.9), 1)
        XCTAssertEqual(zoom.resting(at: 2.1), 4)
        XCTAssertEqual(zoom.moved(from: 1, by: log(2.0)), 2, accuracy: 1e-9, "the fingers spread twice: twice the size")
    }

    /// A SWIPE REACHES ONE SNAP EITHER SIDE of the one it was taken at, and thrown rests on the next that way.
    func testASwipeReachesOneSnapEitherSide() {
        let pages = axis(
            low: 0, high: 4, snaps: .at([0, 1, 2, 3, 4]),
            input: .translation(.horizontal, unit: .points(1), swipes: true))

        XCTAssertEqual(pages.reach(about: 2), 1...3)
        XCTAssertEqual(pages.reach(about: 0), 0...1, "held to the end")
        XCTAssertEqual(pages.swiped(from: 2.1, thrown: 9, about: 2), 3)
        XCTAssertEqual(pages.swiped(from: 2.1, thrown: -9, about: 2), 2, "thrown back: where it was taken")
        XCTAssertEqual(pages.swiped(from: 2.6, thrown: 0, about: 2), 3, "still: the nearest of its reach")
    }

    /// A THROW UNDER AN EASED MOTION FLIES AS A GLIDE NO LONGER THAN TWICE ITS LENGTH; under a glide, as that glide,
    /// its longest the longest; under a spring, as the spring.
    func testAThrowFliesByItsReleasesKind() throws {
        let hand = InteractionAxis.Letting(point: 0.1, per: 100, velocity: 12, end: 1.7)
        func law(_ release: InteractionRelease) throws -> Motion {
            let thrown = axis(low: 0, high: 6, snaps: .at([0, 1, 2, 3, 4, 5, 6]), release: release)
            return try XCTUnwrap(thrown.going(hand, to: 2, under: .eased(.milliseconds(160)))).law
        }

        XCTAssertEqual(try law(.projected(cubicOut)), .glide(longest: .milliseconds(800)))
        XCTAssertEqual(try law(.projected(.glide(longest: .milliseconds(800)))), .glide(longest: .milliseconds(800)))
        let spring = Motion.spring(response: .milliseconds(500), damping: 0.8)
        XCTAssertEqual(try law(.projected(spring)), spring)
    }

    /// A RELEASE THAT THROWS NOTHING CARRIES NOTHING: onto the nearest under its own motion, the hand's speed
    /// choosing nothing; and one that stays is no journey at all.
    func testOnlyAProjectedReleaseThrows() throws {
        let fast = 30.0
        let nearest = axis(low: 0, high: 6, snaps: .at([0, 1, 2, 3, 4, 5, 6]), release: .nearest(.eased(.milliseconds(200))))
        let let1 = nearest.letting(at: 1.2, per: 100, velocity: fast)
        XCTAssertEqual(nearest.rest(of: let1), 1, "the nearest, however fast")
        let going = try XCTUnwrap(nearest.going(let1, to: 1, under: .eased(.milliseconds(900))))
        XCTAssertFalse(going.thrown)
        XCTAssertEqual(going.law, .eased(.milliseconds(40)), "a fifth of a unit, a fifth of its own 200 milliseconds")

        let thrown = axis(low: 0, high: 6, snaps: .at([0, 1, 2, 3, 4, 5, 6]))
        XCTAssertEqual(thrown.rest(of: thrown.letting(at: 1.2, per: 100, velocity: fast)), 5, "thrown on")
        XCTAssertTrue(axis(release: .stay).stays)
    }

    /// AN APPROACH NEVER TAKES LONGER THAN THE MOTION ITSELF: a part of a unit takes that part of its length, a unit
    /// the whole of it, and a value a point a unit comes onto a snap sixty points off in the motion's length - not
    /// sixty of them.
    func testAnApproachNeverTakesLongerThanTheMotion() throws {
        let motion = Motion.eased(.milliseconds(300), curve: .linear)
        XCTAssertEqual(InteractionArithmetic.approach(motion, over: 0.4), .eased(.milliseconds(120), curve: .linear))
        XCTAssertEqual(InteractionArithmetic.approach(motion, over: -1), motion)
        XCTAssertEqual(InteractionArithmetic.approach(motion, over: 60), motion)
        XCTAssertEqual(InteractionArithmetic.approach(motion, over: .nan), .eased(.milliseconds(0), curve: .linear))

        let panel = axis(low: 0, high: 240, snaps: .at([0, 120, 240]), release: .nearest(motion))
        let let1 = panel.letting(at: 60.5, per: 1, velocity: 0)
        XCTAssertEqual(try XCTUnwrap(panel.going(let1, to: 120, under: .eased(.milliseconds(900)))).law, motion)
    }
}
