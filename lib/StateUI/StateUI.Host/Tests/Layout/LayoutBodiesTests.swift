// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A layout's bodies worked out at a fixed step: the same time in other frames brings a body to the same place, a
/// critically damped one comes onto its place without passing it and is a body no more there, a lighter damped one
/// passes it and comes back, bodies far behind work out no more than their most steps, and a body carried keeps
/// where it was shown.
@MainActor
final class LayoutBodiesTests: XCTestCase {
    private let critical = HostLayoutBody(milliseconds: 300, damping: 1, follows: false)

    /// The world with one body 100 from its place, going nowhere, from 0.
    private func world(_ spring: HostLayoutBody) -> LayoutBodies {
        var world = LayoutBodies()
        world.set(1, lanes: [100], velocity: [0], spring: spring, at: 0)
        return world
    }

    /// THE SAME TIME IN OTHER FRAMES IS THE SAME PLACE: the world steps at its own fixed step, whatever frames ask it.
    func testTheSameTimeInOtherFramesIsTheSamePlace() {
        var sixteens = world(critical), sevens = world(critical)
        for frame in 1...12 { sixteens.step(to: Double(frame) * 16) }
        for frame in 1...28 { sevens.step(to: min(Double(frame) * 7, 192)) }

        XCTAssertEqual(sixteens[1], sevens[1])
    }

    /// A CRITICALLY DAMPED BODY COMES ONTO ITS PLACE WITHOUT PASSING IT, and leaves the world at rest there.
    func testACriticallyDampedBodyComesOntoItsPlaceWithoutPassingIt() {
        var world = world(critical)
        var nearest = 100.0
        for frame in 1...200 {
            world.step(to: Double(frame) * 16)
            guard let body = world[1] else { break }
            XCTAssertGreaterThanOrEqual(body.lanes[0], -HostMotionLaw.still, "never past its place")
            XCTAssertLessThanOrEqual(body.lanes[0], nearest + 1e-9, "never back away")
            nearest = body.lanes[0]
        }
        XCTAssertTrue(world.isEmpty, "at rest, gone from the world")
    }

    /// EVERY SPRING A WORLD ADMITS COMES TO AN END: on any response and damping, however far from its place and
    /// however fast, a body's lanes and speeds are numbers at every frame, and it has left the world by the longest a
    /// spring animates.
    func testEverySpringAWorldAdmitsComesToAnEnd() {
        var wrong: [String] = []
        for response in [1.0, 13, 30, 300, 2_000] {
            for damping in [0.05, 0.5, 1, 2, 10, 1e3, 1e6, 1e200] {
                for far in [100, 1e300, 1e307, Double.greatestFiniteMagnitude] {
                    for fast in [0, 500, 1e300, Double.greatestFiniteMagnitude] {
                        var world = LayoutBodies()
                        let spring = HostLayoutBody(milliseconds: response, damping: damping, follows: false)
                        world.set(1, lanes: [far, -far / 2], velocity: [fast, 0], spring: spring, at: 0)
                        var frame = 0.0
                        while !world.isEmpty, frame <= HostMotionLaw.longest + 16 {
                            frame += 1_000 / 240
                            world.step(to: frame)
                            if let body = world[1], !(body.lanes + body.velocity).allSatisfy(\.isFinite) {
                                wrong.append("\(response) ms, \(damping), \(far), \(fast): \(body.velocity) at \(frame)")
                                break
                            }
                        }
                        if !world.isEmpty { wrong.append("\(response) ms, \(damping), \(far), \(fast): still in the world") }
                    }
                }
            }
        }
        XCTAssertEqual(wrong.count, 0, "\(wrong.prefix(5))")
    }

    /// A LIGHTER DAMPED BODY PASSES ITS PLACE AND COMES BACK.
    func testALighterDampedBodyPassesItsPlaceAndComesBack() {
        var world = world(HostLayoutBody(milliseconds: 300, damping: 0.5, follows: false))
        var passed = false
        for frame in 1...300 {
            world.step(to: Double(frame) * 16)
            if let body = world[1], body.lanes[0] < -1 { passed = true }
        }
        XCTAssertTrue(passed, "past its place")
        XCTAssertTrue(world.isEmpty, "and back on it, at rest")
    }

    /// A WORLD FAR BEHIND WORKS OUT NO MORE THAN ITS MOST STEPS: a second at once is 32 steps, and the rest let go.
    func testAWorldFarBehindWorksOutNoMoreThanItsMostSteps() {
        var behind = world(critical), stepped = world(critical)
        behind.step(to: 1_000)
        stepped.step(to: Double(LayoutBodies.mostSteps) * LayoutBodies.step)

        XCTAssertEqual(behind[1], stepped[1])
        behind.step(to: 1_016)
        stepped.step(to: Double(LayoutBodies.mostSteps) * LayoutBodies.step + 16)
        XCTAssertEqual(behind[1]?.lanes[0] ?? 0, stepped[1]?.lanes[0] ?? 0, accuracy: 1e-9, "going on from there")
    }

    /// A BODY CARRIED KEEPS WHERE IT WAS SHOWN: its place moved, it stands as far off the other way, and one carried
    /// by nothing makes no body.
    func testABodyCarriedKeepsWhereItWasShown() {
        var world = LayoutBodies()
        world.carry(1, by: [0], spring: critical, at: 0)
        XCTAssertNil(world[1], "carried by nothing")

        world.carry(1, by: [-40], spring: critical, at: 0)
        world.carry(1, by: [-10], spring: critical, at: 0)
        XCTAssertEqual(world[1]?.lanes, [-50])
        XCTAssertEqual(world[1]?.velocity, [0])
    }
}
