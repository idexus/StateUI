// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

/// The two motion laws every runtime animates with, as numbers.
///
/// The trajectory table below is the conformance suite for an animator in
/// another language: `motion-laws.txt` is written from it, and the MAUI host's
/// `MotionLawTests.cs` runs every animation in the file to the same numbers.
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

    /// The table every runtime's animator is held to.
    ///
    /// Compared number by number to a billionth rather than as text: the
    /// platforms' maths libraries may round `exp`, `sin` and `cos` differently
    /// in the last digit, and the fixture is written on one of them.
    func testEveryRuntimeWalksTheTrajectoriesInTheFixture() throws {
        let written = Self.table()
        let fixture = Fixtures.directory.appendingPathComponent("motion-laws.txt")

        if Fixtures.updating {
            try written.write(to: fixture, atomically: true, encoding: .utf8)
            return
        }

        let expected = try String(contentsOf: fixture, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
        let walked = written.split(separator: "\n", omittingEmptySubsequences: false)

        XCTAssertEqual(
            expected.count, walked.count,
            """
            The table no longer has the fixture's lines. If a animation was added or \
            changed on purpose, run the tests again with STATEUI_UPDATE_FIXTURES=1 \
            and read the diff of motion-laws.txt.
            """)

        for (line, (fixed, now)) in zip(expected, walked).enumerated() {
            XCTAssertTrue(
                Self.agree(fixed, now),
                "line \(line + 1) walks to\n\(now)\nwhere the fixture says\n\(fixed)")
        }
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

        // A animation that began moving: the Hermite on a lane with speed, the
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

    /// The table as the fixture holds it.
    private static func table() -> String {
        var lines = [
            "# The trajectories every runtime's animator answers: at an elapsed time",
            "# in milliseconds, the value and the velocity per millisecond of every",
            "# lane, and whether the animation has arrived. Written by MotionLawTests.swift",
            "# with STATEUI_UPDATE_FIXTURES=1; walked by MotionLawTests.cs.",
            "#",
            "# animation <law> <curve> <milliseconds> <damping> from <lanes> to <lanes> velocity <lanes>",
            "# at <elapsed> <moving|rested> value <lanes> velocity <lanes>",
        ]

        func lanes(_ values: [Double]) -> String {
            values.map { "\($0)" }.joined(separator: ",")
        }

        for animation in animations {
            let motion = animation.motion
            lines.append(
                "animation \(motion.law == .spring ? "spring" : "eased") \(motion.curve) "
                    + "\(motion.millis) \(motion.factor) from \(lanes(animation.from)) "
                    + "to \(lanes(animation.destination)) velocity \(lanes(animation.velocity))")

            for instant in animation.instants {
                let sample = HostMotionLaw.sample(
                    motion, elapsed: instant,
                    from: animation.from, destination: animation.destination, velocity: animation.velocity)
                lines.append(
                    "at \(instant) \(sample.rested ? "rested" : "moving") "
                        + "value \(lanes(sample.value)) velocity \(lanes(sample.velocity))")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Whether two lines say the same: the same words, and numbers equal to a
    /// billionth of the larger.
    private static func agree(_ fixed: Substring, _ now: Substring) -> Bool {
        let separators: Set<Character> = [" ", ","]
        let fixedWords = fixed.split(whereSeparator: separators.contains)
        let nowWords = now.split(whereSeparator: separators.contains)

        guard fixedWords.count == nowWords.count else { return false }

        return zip(fixedWords, nowWords).allSatisfy { fixed, now in
            guard let a = Double(fixed), let b = Double(now) else { return fixed == now }
            return abs(a - b) <= 1e-9 * max(1, abs(a), abs(b))
        }
    }
}
