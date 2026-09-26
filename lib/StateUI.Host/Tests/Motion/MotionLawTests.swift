// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// The two motion laws every runtime animates with, as numbers - and the
/// promises every animation of the table below keeps.
final class MotionLawTests: XCTestCase {
    func testAnEasedAnimationIsAFunctionOfElapsedTime() {
        let halfway = HostMotionLaw.sample(
            .eased(200, .cubicOut), elapsed: 100, from: [0], destination: [1], velocity: [0])
        let landed = HostMotionLaw.sample(
            .eased(200, .cubicOut), elapsed: 200, from: [0], destination: [1], velocity: [0])

        XCTAssertEqual(halfway.value[0], 0.875, accuracy: 0.000_001)
        XCTAssertFalse(halfway.rested)
        XCTAssertEqual(landed, HostMotionSample(value: [1], velocity: [0], rested: true))
    }

    func testAnAnimationThatBeganMovingStartsAtItsSpeedAndLandsStill() {
        let motion = Motion.eased(300, .cubicOut)
        let start = HostMotionLaw.sample(
            motion, elapsed: 0, from: [20], destination: [80], velocity: [0.3])
        let late = HostMotionLaw.sample(
            motion, elapsed: 299.9, from: [20], destination: [80], velocity: [0.3])
        let landed = HostMotionLaw.sample(
            motion, elapsed: 300, from: [20], destination: [80], velocity: [0.3])

        XCTAssertEqual(start.value[0], 20, accuracy: 1e-12)
        XCTAssertEqual(start.velocity[0], 0.3, accuracy: 1e-12)
        XCTAssertEqual(late.velocity[0], 0, accuracy: HostMotionLaw.still)
        XCTAssertEqual(landed, HostMotionSample(value: [80], velocity: [0], rested: true))
    }

    func testASpringAnswersTheSameValueForTheSameInstant() {
        let first = HostMotionLaw.sample(
            .spring(response: 260, damping: 0.8),
            elapsed: 147, from: [20, -4], destination: [80, 10], velocity: [0.03, -0.01])
        let second = HostMotionLaw.sample(
            .spring(response: 260, damping: 0.8),
            elapsed: 147, from: [20, -4], destination: [80, 10], velocity: [0.03, -0.01])

        XCTAssertEqual(first, second)
        XCTAssertFalse(first.rested)
    }

    func testASpringRestsWhenStillAndNeverOutlivesItsLongestWalk() {
        let settled = HostMotionLaw.sample(
            .spring(response: 260, damping: 0.8),
            elapsed: 3_000, from: [0], destination: [1], velocity: [0])
        let loose = HostMotionLaw.sample(
            .spring(response: 100_000, damping: 0.01),
            elapsed: HostMotionLaw.longest, from: [0], destination: [1], velocity: [0])

        XCTAssertEqual(settled, HostMotionSample(value: [1], velocity: [0], rested: true))
        XCTAssertEqual(loose, HostMotionSample(value: [1], velocity: [0], rested: true))
    }

    func testLanesThatDoNotPairUpLandAtOnce() {
        let sample = HostMotionLaw.sample(
            .eased(300), elapsed: 0, from: [0, 1], destination: [5], velocity: [0])

        XCTAssertEqual(sample, HostMotionSample(value: [5], velocity: [0], rested: true))
    }

    /// Every animation of the table starts where it began - a lane that was
    /// moving at the speed it was moving - and lands exactly on its
    /// destination, at rest, and stays there: an eased one at its duration and
    /// not before, a spring by the longest walk at the latest. `.none` has
    /// arrived before it starts.
    func testEveryAnimationStartsWhereItBeganAndLandsAtRest() {
        for animation in Self.animations {
            let motion = animation.motion
            let named = "\(motion) from \(animation.from)"
            let start = Self.sample(animation, at: 0)

            if motion.isNothing {
                XCTAssertEqual(start, HostMotionSample(value: animation.destination, velocity: [0], rested: true))
                continue
            }

            for lane in animation.from.indices {
                XCTAssertEqual(start.value[lane], animation.from[lane], accuracy: 1e-12, named)
                if animation.velocity[lane] != 0, motion.law == .eased {
                    XCTAssertEqual(start.velocity[lane], animation.velocity[lane], accuracy: 1e-12, named)
                }
            }

            let landed = Self.sample(animation, at: motion.law == .eased ? Double(motion.millis) : HostMotionLaw.longest)
            XCTAssertEqual(
                landed,
                HostMotionSample(
                    value: animation.destination,
                    velocity: Array(repeating: 0, count: animation.destination.count), rested: true),
                named)

            for instant in animation.instants {
                let sample = Self.sample(animation, at: instant)
                if motion.law == .eased {
                    XCTAssertEqual(sample.rested, instant >= Double(motion.millis), "\(named) at \(instant)")
                }
                if sample.rested {
                    XCTAssertEqual(sample.value, animation.destination, "\(named) stays at rest")
                }
            }
        }
    }

    /// A spring damped at 1 or more never passes its destination; one damped
    /// below 1 rings past it before it settles - unless it is too slow to come
    /// round before the longest walk ends it.
    func testASpringRingsOnlyBelowCriticalDamping() {
        for animation in Self.animations
        where animation.motion.law == .spring && Double(animation.motion.millis) < HostMotionLaw.longest {
            let passes = stride(from: 0.0, through: HostMotionLaw.longest, by: 5).contains { instant in
                let sample = Self.sample(animation, at: instant)
                return animation.from.indices.contains { lane in
                    let span = animation.destination[lane] - animation.from[lane]
                    return span != 0 && (sample.value[lane] - animation.destination[lane]) / span > 1e-9
                }
            }

            XCTAssertEqual(
                passes, animation.motion.factor < 1,
                "\(animation.motion) from \(animation.from) passing its destination")
        }
    }

    /// Where one animation of the table stands at an elapsed time.
    private static func sample(_ animation: Animation, at elapsed: Double) -> HostMotionSample {
        HostMotionLaw.sample(
            animation.motion, elapsed: elapsed,
            from: animation.from, destination: animation.destination, velocity: animation.velocity)
    }

    // MARK: - The table

    /// One animation: a law, where each lane began, and the instants it is read at.
    private struct Animation {
        let motion: Motion
        let from: [Double]
        let destination: [Double]
        let velocity: [Double]
        let instants: [Double]
    }

    private static var animations: [Animation] {
        var animations: [Animation] = []

        // Every curve, from a standstill. `Easing` lists no cases, so its raw
        // values are walked until one is missing - a curve appended later is
        // in the table the day it arrives.
        var raw: Int32 = 0
        while let curve = Easing(rawValue: raw) {
            animations.append(Animation(
                motion: .eased(400, curve),
                from: [0, 20], destination: [1, -40], velocity: [0, 0],
                instants: [0, 40, 100, 200, 300, 360, 399, 400, 480]))
            raw += 1
        }

        // An animation that began moving: the Hermite on a lane with speed, the
        // curve on a lane without.
        animations.append(Animation(
            motion: .eased(300, .cubicOut),
            from: [20, -4], destination: [80, 10], velocity: [0.3, 0],
            instants: [0, 30, 75, 150, 225, 290, 300]))
        animations.append(Animation(
            motion: .eased(250, .sineInOut),
            from: [1], destination: [0], velocity: [-0.004],
            instants: [0, 25, 125, 249, 250]))

        // Springs: critically damped from rest and moving, ringing, crawling.
        let spring: [Double] = [0, 16, 50, 100, 200, 400, 800, 1_600, 3_200]
        animations.append(Animation(
            motion: .spring(response: 260),
            from: [0], destination: [100], velocity: [0], instants: spring))
        animations.append(Animation(
            motion: .spring(response: 260),
            from: [0, 50], destination: [100, 50], velocity: [0.5, -0.2], instants: spring))
        animations.append(Animation(
            motion: .spring(response: 400, damping: 0.5),
            from: [0], destination: [1], velocity: [0], instants: spring + [6_400]))
        animations.append(Animation(
            motion: .spring(response: 200, damping: 1.8),
            from: [10, 0], destination: [0, 5], velocity: [0, 0.01], instants: spring))

        // A spring too loose to settle is over at the longest walk anyway.
        animations.append(Animation(
            motion: .spring(response: 100_000, damping: 0.05),
            from: [0], destination: [1], velocity: [0],
            instants: [0, 5_000, 9_999, 10_000]))

        // No motion: the animation has arrived before it starts.
        animations.append(Animation(
            motion: .none, from: [3], destination: [7], velocity: [0], instants: [0]))

        return animations
    }
}
