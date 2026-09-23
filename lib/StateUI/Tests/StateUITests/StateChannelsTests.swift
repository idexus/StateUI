// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// One state channel per host-carried state: every control tied to the state
/// stands at its value, a retarget keeps the velocity, a landing writes the
/// exact destination and a waiter hears once.
final class StateChannelsTests: XCTestCase {
    @MainActor
    func testOneStateNumberOwnsOneChannelAcrossControls() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 7, mode: .inOut, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .cubicOut),
            completion: nil,
            stopped: 0)
        let carried = StateUIHost.value(of: journey)

        _ = channels.presentedValue(
            for: binding, from: carried, now: 0, reducesMotion: false)
        _ = channels.presentedValue(
            for: binding, from: carried, now: 0, reducesMotion: false)
        XCTAssertEqual(channels.takeOutputs().count, 1, "the second wearer reuses the channel")

        channels.follow(animator.advance(to: 100))
        let frame = try XCTUnwrap(channels.takeOutputs().last)

        XCTAssertEqual(frame.state, 7)
        XCTAssertEqual(frame.journey.value[0], 0.875, accuracy: 0.000_001)
        XCTAssertEqual(frame.report, .frame)
    }

    @MainActor
    func testRetargetingCarriesTheCurrentVelocityIntoTheNewMotion() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 9, mode: .inOut, kind: .property)
        let first = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .cubicOut),
            completion: nil,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: StateUIHost.value(of: first),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        let second = HostJourney(
            value: [0],
            destination: [0.2],
            velocity: [0],
            motion: .eased(200, .linear),
            completion: nil,
            stopped: 0)
        channels.receive(
            HostStateChange(
                state: 9,
                changed: 1 << 1,
                value: StateUIHost.value(of: second)),
            now: 100,
            reducesMotion: false)

        let aimed = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(aimed.journey.value[0], 0.875, accuracy: 0.000_001)
        XCTAssertEqual(aimed.journey.velocity[0], 3.75, accuracy: 0.01)

        channels.follow(animator.advance(to: 101))
        let next = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertGreaterThan(next.journey.value[0], aimed.journey.value[0])
    }

    @MainActor
    func testACompletedMotionReportsItsExactDestinationOnce() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 11, mode: .inOut, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(100, .linear),
            completion: -23,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: StateUIHost.value(of: journey),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        channels.follow(animator.advance(to: 100))
        let landed = try XCTUnwrap(channels.takeOutputs().last)

        XCTAssertEqual(landed.journey.value, [1])
        XCTAssertEqual(landed.journey.velocity, [0])
        XCTAssertEqual(landed.report, .position)
        XCTAssertEqual(
            channels.takeCompletions(),
            [JourneyCompletion(id: -23, succeeded: true)])

        channels.follow(animator.advance(to: 200))
        XCTAssertTrue(channels.takeOutputs().isEmpty)
        XCTAssertTrue(channels.takeCompletions().isEmpty)
    }

    @MainActor
    func testEnablingReducedMotionLandsAnActiveJourneyAndItsWaiter() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 12, mode: .inOut, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .linear),
            completion: -29,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: StateUIHost.value(of: journey),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        channels.follow(animator.advance(to: 50, reducesMotion: true))
        let landed = try XCTUnwrap(channels.takeOutputs().last)

        XCTAssertEqual(landed.journey.value, [1])
        XCTAssertEqual(landed.journey.destination, [1])
        XCTAssertEqual(landed.journey.velocity, [0])
        XCTAssertEqual(landed.report, .position)
        XCTAssertEqual(
            channels.takeCompletions(),
            [JourneyCompletion(id: -29, succeeded: true)])
        XCTAssertFalse(channels.isActive)
    }

    @MainActor
    func testAReaderTakesAnActiveJourneyAtItsOwnPosition() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 13, mode: .inOut, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .cubicOut),
            completion: -31,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: StateUIHost.value(of: journey),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        XCTAssertTrue(channels.take([0.4], through: binding))
        let taken = try XCTUnwrap(channels.takeOutputs().last)

        XCTAssertEqual(taken.journey.value, [0.4])
        XCTAssertEqual(taken.journey.destination, [0.4])
        XCTAssertEqual(taken.journey.velocity, [0])
        XCTAssertEqual(taken.report, .position)
        XCTAssertFalse(channels.isActive)
        XCTAssertEqual(
            channels.takeCompletions(),
            [JourneyCompletion(id: -31, succeeded: false)])
    }

    @MainActor
    func testAnOutputOnlyBindingCannotTakeItsJourney() {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 15, mode: .out, kind: .property)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(200, .linear),
            completion: nil,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: StateUIHost.value(of: journey),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        XCTAssertFalse(channels.take([0.4], through: binding))
        XCTAssertTrue(channels.isActive)
        XCTAssertTrue(channels.takeOutputs().isEmpty)
    }

    @MainActor
    func testAStateSnapCancelsItsWaiterOnceWithoutRebookingIt() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 17, mode: .inOut, kind: .property)
        let moving = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(100, .linear),
            completion: -41,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: StateUIHost.value(of: moving),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        let snapped = HostJourney(
            value: [0.25],
            destination: [0.25],
            velocity: [0],
            motion: moving.motion,
            completion: -41,
            stopped: 0)
        channels.receive(
            HostStateChange(
                state: 17,
                changed: 0b11,
                value: StateUIHost.value(of: snapped)),
            now: 50,
            reducesMotion: false)

        let applied = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(applied.journey.value, [0.25])
        XCTAssertEqual(applied.journey.destination, [0.25])
        XCTAssertEqual(applied.journey.velocity, [0])
        XCTAssertEqual(applied.report, .position)
        XCTAssertFalse(channels.isActive)
        XCTAssertEqual(
            channels.takeCompletions(),
            [JourneyCompletion(id: -41, succeeded: false)])

        channels.follow(animator.advance(to: 200))
        XCTAssertTrue(channels.takeOutputs().isEmpty)
        XCTAssertTrue(channels.takeCompletions().isEmpty)
    }

    @MainActor
    func testAnAwaitedRetargetOwnsItsNewCompletion() {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 19, mode: .inOut, kind: .property)
        let first = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(100, .linear),
            completion: -41,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: StateUIHost.value(of: first),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        let second = HostJourney(
            value: [0],
            destination: [0.25],
            velocity: [0],
            motion: .eased(100, .linear),
            completion: -42,
            stopped: 0)
        channels.receive(
            HostStateChange(
                state: 19,
                changed: (1 << 1) | (1 << 6),
                value: StateUIHost.value(of: second)),
            now: 50,
            reducesMotion: false)

        XCTAssertEqual(
            channels.takeCompletions(),
            [JourneyCompletion(id: -41, succeeded: false)])

        channels.follow(animator.advance(to: 150))
        XCTAssertEqual(
            channels.takeCompletions(),
            [JourneyCompletion(id: -42, succeeded: true)])
    }
}
