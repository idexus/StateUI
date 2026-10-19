// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A state channel lane by lane: a write of some lanes - a destination, a value - leaves the other lanes' travel
/// and their waiter as they were, so the axes of one state move on their own.
@MainActor
final class ChannelLanesTests: XCTestCase {
    /// The state the tests open, of two lanes.
    private let binding = HostStateBinding(state: 31, mode: .inOut, kind: .property, laneKind: .number)

    /// A NEW DESTINATION OF ONE LANE LEAVES THE OTHER'S TRAVEL AS IT IS: it lands when it would have.
    func testANewDestinationOfOneLaneLeavesTheOthersTravelAsItIs() throws {
        let (animator, channels) = opened(completion: nil)

        aim(channels, destination: [2, 1], changed: Self.destination(0), at: 100)
        channels.follow(animator.advance(to: 200))
        let frame = try XCTUnwrap(channels.takeOutputs().last)

        XCTAssertEqual(frame.journey.value[1], 1, "the other lane landed when it was due")
        XCTAssertGreaterThan(frame.journey.value[0], 0.5, "the lane sent on is on its new way")
        XCTAssertLessThan(frame.journey.value[0], 2)
        XCTAssertTrue(channels.isActive)
    }

    /// A WAITER OF SOME LANES IS ANSWERED WHEN THEY ARRIVE, though another lane was sent elsewhere meanwhile.
    func testAWaiterIsAnsweredWhenItsLanesArriveThoughAnotherWasSentOn() {
        let (animator, channels) = opened(completion: nil)

        aim(channels, destination: [1, 3], changed: Self.destination(1) | Self.completion, completion: -51, at: 50)
        aim(channels, destination: [2, 3], changed: Self.destination(0), at: 100)
        XCTAssertEqual(channels.takeCompletions(), [], "the second lane's waiter is not the first lane's")

        channels.follow(animator.advance(to: 250))
        XCTAssertEqual(channels.takeCompletions(), [JourneyCompletion(id: -51, succeeded: true)])
    }

    /// A RUN CUT SHORT FAILS ITS WAITER ONCE, and the lanes it keeps travel on to where they were going.
    func testARunCutShortFailsItsWaiterOnceAndItsOtherLanesTravelOn() throws {
        let (animator, channels) = opened(completion: -52)

        aim(channels, destination: [0, 1], changed: Self.destination(0), at: 100)
        XCTAssertEqual(channels.takeCompletions(), [JourneyCompletion(id: -52, succeeded: false)])

        channels.follow(animator.advance(to: 200))
        XCTAssertEqual(try XCTUnwrap(channels.takeOutputs().last).journey.value[1], 1, "the lane it kept, landed")
        XCTAssertEqual(channels.takeCompletions(), [], "and nobody answered twice")
    }

    /// A VALUE WRITTEN TO ONE LANE STOPS THAT LANE ALONE: it stands where it was written, the other travels on.
    func testAValueWrittenToOneLaneStopsItAlone() throws {
        let (animator, channels) = opened(completion: nil)

        let written = HostJourney(
            value: [0.3, 0], destination: [0.3, 1], velocity: [0, 0], motion: Self.law, completion: nil, stopped: 0)
        channels.receive(
            HostStateChange(state: binding.state, changed: Self.value(0) | Self.destination(0),
                            value: HostBoundary.value(of: written)),
            now: 100, reducesMotion: false)

        channels.follow(animator.advance(to: 150))
        let frame = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(frame.journey.value[0], 0.3, "where it was written")
        XCTAssertEqual(frame.journey.value[1], 0.75, accuracy: 0.000_001, "the other on its way, on time")
    }

    /// A WHOLE WRITE IS ONE RUN, as before: both lanes sent on together, under one waiter.
    func testAWriteOfEveryLaneIsOneRun() {
        let (animator, channels) = opened(completion: -53)

        aim(channels, destination: [2, 2], changed: Self.destination(0) | Self.destination(1) | Self.completion,
            completion: -54, at: 100)
        XCTAssertEqual(channels.takeCompletions(), [JourneyCompletion(id: -53, succeeded: false)])

        channels.follow(animator.advance(to: 400))
        XCTAssertEqual(channels.takeCompletions(), [JourneyCompletion(id: -54, succeeded: true)])
        XCTAssertFalse(channels.isActive)
    }

    // MARK: - The bench

    /// The law every journey here travels under: 200 ms, straight.
    private static let law = Motion.eased(.milliseconds(200), .linear)

    /// The dirty bit of a lane of a two-lane journey: its value, its destination, its waiter.
    private static func value(_ lane: Int) -> UInt64 { 1 << UInt64(lane) }
    private static func destination(_ lane: Int) -> UInt64 { 1 << UInt64(2 + lane) }
    private static let completion: UInt64 = 1 << 9

    /// The channel opened at 0 ms on a journey of both lanes from 0 to 1, under `completion`.
    private func opened(completion: Int?) -> (Animator, StateChannels) {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let journey = HostJourney(
            value: [0, 0], destination: [1, 1], velocity: [0, 0], motion: Self.law, completion: completion, stopped: 0)

        _ = channels.presentedValue(for: binding, from: HostBoundary.value(of: journey), now: 0, reducesMotion: false)
        _ = channels.takeOutputs()

        return (animator, channels)
    }

    /// The core sends the lanes `changed` names to `destination` at `now`.
    private func aim(
        _ channels: StateChannels, destination: [Double], changed: UInt64, completion: Int? = nil, at now: Double
    ) {
        let journey = HostJourney(
            value: [0, 0], destination: destination, velocity: [0, 0], motion: Self.law, completion: completion,
            stopped: 0)

        channels.receive(
            HostStateChange(state: binding.state, changed: changed, value: HostBoundary.value(of: journey)),
            now: now, reducesMotion: false)
    }
}
