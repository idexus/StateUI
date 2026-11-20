// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A lane of a state a hand holds: shown where the hand holds it and bound for where it would rest, the other
/// lanes traveling on; let go, sent on as the user's; and a program's write of it taking it from the hand, or
/// waiting for the hand to let go.
@MainActor
final class StateChannelHandTests: XCTestCase {
    private let linear = Motion.eased(.milliseconds(200), curve: .linear)

    /// Channels with one state of two lanes, standing at `value` and going to `destination`.
    private func channels(
        value: [Double] = [0, 0], destination: [Double] = [0, 0], completion: Int? = nil
    ) -> (StateChannels, Animator) {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        channels.attach(5)
        let journey = HostJourney(
            value: value, destination: destination, velocity: [0, 0], motion: linear, completion: completion,
            stopped: 0)
        _ = channels.presentedValue(
            for: HostStateBinding(state: 5, mode: .inOut, kind: .property, laneKind: .number),
            from: HostBoundary.value(of: journey), now: 0, reducesMotion: false)
        _ = channels.takeOutputs()
        _ = channels.takeCompletions()
        return (channels, animator)
    }

    /// The program writes the destinations `to`, naming the lanes in `lanes`, at `now`.
    private func write(
        _ channels: StateChannels, to: [Double], lanes: [Int], completion: Int? = nil, at now: Double
    ) {
        var changed: UInt64 = 0
        for lane in lanes { changed |= 1 << UInt64(2 + lane) }
        if completion != nil { changed |= 1 << UInt64(6 + 3) }
        let journey = HostJourney(
            value: [0, 0], destination: to, velocity: [0, 0], motion: linear, completion: completion, stopped: 0)
        channels.receive(
            HostStateChange(state: 5, changed: changed, value: HostBoundary.value(of: journey)), now: now,
            reducesMotion: false)
    }

    /// A HELD LANE IS SHOWN UNDER THE HAND AND BOUND FOR ITS REST, said as the user's - and the lane beside it
    /// travels on as it was.
    func testAHeldLaneIsShownUnderTheHandAndTheOtherTravelsOn() throws {
        let (channels, animator) = channels(destination: [1, 1])

        channels.follow(animator.advance(to: 100))
        _ = channels.takeOutputs()
        XCTAssertTrue(channels.hold(5, [HeldLane(lane: 0, value: 0.4, destination: 0)]))

        let held = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(held.origin, .user)
        XCTAssertEqual(held.report, .position, "its destination moved: the state is told")
        XCTAssertEqual(held.journey.value[0], 0.4)
        XCTAssertEqual(held.journey.destination[0], 0)
        XCTAssertEqual(held.journey.velocity[0], 0)
        XCTAssertEqual(channels.held(5), [0])

        channels.follow(animator.advance(to: 150))
        let frame = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(frame.journey.value[0], 0.4, "the hand's lane stands under the hand")
        XCTAssertEqual(frame.journey.value[1], 0.75, accuracy: 0.000_001, "the other lane's run goes on")
    }

    /// A HAND MOVING BETWEEN TWO SNAPS SAYS A FRAME, NOT A DESTINATION: where the lane would rest did not change,
    /// so the state hears nothing of where it is going.
    func testAHoldThatNamesNoNewRestSaysAFrame() throws {
        let (channels, _) = channels()

        channels.hold(5, [HeldLane(lane: 0, value: 0.2, destination: 0)])
        XCTAssertEqual(try XCTUnwrap(channels.takeOutputs().last).report, .frame)

        channels.hold(5, [HeldLane(lane: 0, value: 0.6, destination: 1)])
        XCTAssertEqual(try XCTUnwrap(channels.takeOutputs().last).report, .position)
    }

    /// LET GO, THE LANES SET OUT TOGETHER FROM WHERE THE HAND LEFT THEM, each at its speed, under the law given -
    /// one run, said as the user's - and land on their destinations.
    func testLetGoTheLanesGoOnTogetherUnderTheLawGiven() throws {
        let (channels, animator) = channels()

        channels.hold(5, [HeldLane(lane: 0, value: 0.5, destination: 1), HeldLane(lane: 1, value: 0.2, destination: 0)])
        _ = channels.takeOutputs()
        channels.release(
            5,
            [
                ReleasedLane(lane: 0, from: 0.5, destination: 1, velocity: 0),
                ReleasedLane(lane: 1, from: 0.2, destination: 0, velocity: 0),
            ],
            under: .eased(.milliseconds(100), curve: .linear), now: 1_000, reducesMotion: false)

        let sent = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(sent.origin, .user)
        XCTAssertEqual(sent.report, .position)
        XCTAssertEqual(sent.journey.destination, [1, 0])
        XCTAssertTrue(channels.held(5).isEmpty)

        channels.follow(animator.advance(to: 1_050))
        let half = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(half.journey.value[0], 0.75, accuracy: 0.000_001)
        XCTAssertEqual(half.journey.value[1], 0.1, accuracy: 0.000_001)

        channels.follow(animator.advance(to: 1_100))
        XCTAssertEqual(try XCTUnwrap(channels.takeOutputs().last).journey.value, [1, 0])
    }

    /// A LANE THAT STAYS RESTS WHERE IT IS LET GO, with no travel: it sets out from its rest.
    func testALaneLetGoAtItsRestTravelsNowhere() throws {
        let (channels, animator) = channels()

        channels.hold(5, [HeldLane(lane: 0, value: 0.37, destination: 0.37)])
        channels.release(
            5, [ReleasedLane(lane: 0, from: 0.37, destination: 0.37, velocity: 0)], now: 16, reducesMotion: false)

        let rested = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(rested.journey.value[0], 0.37)
        XCTAssertFalse(animator.isMoving, "nothing travels")
    }

    /// A PROGRAM'S WRITE TAKES THE LANE FROM THE HAND, unless the hand waits for it: whoever holds it is asked to
    /// let go first, and the write travels from where the hand held the lane.
    func testAProgramsWriteTakesTheLaneFromTheHand() throws {
        let (channels, animator) = channels()
        var asked: [(state: Int32, lanes: [Int])] = []
        channels.interrupts = { asked.append(($0, $1)) }

        channels.hold(5, [HeldLane(lane: 0, value: 0.5, destination: 0)])
        _ = channels.takeOutputs()
        write(channels, to: [1, 0], lanes: [0], at: 0)

        XCTAssertEqual(asked.map(\.state), [5])
        XCTAssertEqual(asked.first?.lanes, [0])
        XCTAssertTrue(channels.held(5).isEmpty, "the hand holds it no longer")

        channels.follow(animator.advance(to: 100))
        let frame = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(frame.journey.value[0], 0.75, accuracy: 0.000_001, "from under the hand, halfway on")
    }

    /// A WRITE OF A LANE NO HAND HOLDS ASKS NOBODY, the lane beside it held or not.
    func testAWriteOfAnotherLaneLeavesTheHandItsOwn() throws {
        let (channels, _) = channels()
        var asked = 0
        channels.interrupts = { _, _ in asked += 1 }

        channels.hold(5, [HeldLane(lane: 0, value: 0.5, destination: 0)])
        write(channels, to: [0, 1], lanes: [1], at: 0)

        XCTAssertEqual(asked, 0)
        XCTAssertEqual(channels.held(5), [0])
    }

    /// A HAND THAT WAITS KEEPS THE LANE: the program's write is the state's destination at once, the lane stays
    /// under the hand, a move after it names no rest over it - and let go, the lane goes where the program sent it
    /// last, under the state's own law, answering that write's waiter.
    func testAHandThatWaitsKeepsTheLaneAndGoesWhereTheProgramSentItLast() throws {
        let (channels, animator) = channels()
        var asked = 0
        channels.interrupts = { _, _ in asked += 1 }

        channels.hold(5, [HeldLane(lane: 0, value: 0.5, destination: 0)], defers: true)
        write(channels, to: [3, 0], lanes: [0], at: 0)
        write(channels, to: [2, 0], lanes: [0], completion: -9, at: 0)
        XCTAssertEqual(asked, 0, "the hand is not asked to let go")
        XCTAssertEqual(channels.standing(5, now: 0)?.value[0], 0.5, "the lane stays under the hand")
        XCTAssertEqual(channels.standing(5, now: 0)?.destination[0], 2, "bound for where the program sent it last")

        _ = channels.takeOutputs()
        channels.hold(5, [HeldLane(lane: 0, value: 0.7, destination: 1)], defers: true)
        let moved = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(moved.report, .frame, "the hand names no rest over the program's")
        XCTAssertEqual(moved.journey.destination[0], 2)

        channels.release(
            5, [ReleasedLane(lane: 0, from: 0.7, destination: 1, velocity: 4)],
            under: .eased(.milliseconds(50), curve: .linear), now: 0, reducesMotion: false)
        XCTAssertEqual(try XCTUnwrap(channels.takeOutputs().last).journey.destination[0], 2)

        channels.follow(animator.advance(to: 100))
        XCTAssertEqual(
            try XCTUnwrap(channels.takeOutputs().last).journey.value[0], 1.35, accuracy: 0.000_001,
            "halfway there under the state's own 200 milliseconds")
        channels.follow(animator.advance(to: 200))
        XCTAssertEqual(channels.takeCompletions(), [JourneyCompletion(id: -9, outcome: .animated)])
    }

    /// A STATE WITH NO CHANNEL HOLDS NOTHING: nothing shows it, so no hand has it.
    func testAStateWithNoChannelIsNotHeld() {
        let channels = StateChannels(animator: Animator())

        XCTAssertFalse(channels.hold(3, [HeldLane(lane: 0, value: 1, destination: 1)]))
        XCTAssertFalse(channels.release(3, [], now: 0, reducesMotion: false))
        XCTAssertNil(channels.standing(3, now: 0))
    }
}
