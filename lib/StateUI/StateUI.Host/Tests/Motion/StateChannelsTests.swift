// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// One state channel per host-carried state: every control tied to the state
/// stands at its value, a retarget keeps the velocity, a landing writes the
/// exact destination and a waiter hears once.
@MainActor
final class StateChannelsTests: XCTestCase {
    @MainActor
    func testOneStateNumberOwnsOneChannelAcrossControls() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 7, mode: .inOut, kind: .property, laneKind: .number)
        channels.attach(7)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(.milliseconds(200)),
            completion: nil,
            stopped: 0)
        let carried = HostBoundary.value(of: journey)

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
        let binding = HostStateBinding(state: 9, mode: .inOut, kind: .property, laneKind: .number)
        channels.attach(9)
        let first = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(.milliseconds(200)),
            completion: nil,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: HostBoundary.value(of: first),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        let second = HostJourney(
            value: [0],
            destination: [0.2],
            velocity: [0],
            motion: .eased(.milliseconds(200), curve: .linear),
            completion: nil,
            stopped: 0)
        channels.receive(
            HostStateChange(
                state: 9,
                changed: 1 << 1,
                value: HostBoundary.value(of: second)),
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
        let binding = HostStateBinding(state: 11, mode: .inOut, kind: .property, laneKind: .number)
        channels.attach(11)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(.milliseconds(100), curve: .linear),
            completion: -23,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: HostBoundary.value(of: journey),
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
            [JourneyCompletion(id: -23, outcome: .animated)])

        channels.follow(animator.advance(to: 200))
        XCTAssertTrue(channels.takeOutputs().isEmpty)
        XCTAssertTrue(channels.takeCompletions().isEmpty)
    }

    @MainActor
    func testEnablingReducedMotionLandsAnActiveJourneyAndItsWaiter() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 12, mode: .inOut, kind: .property, laneKind: .number)
        channels.attach(12)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(.milliseconds(200), curve: .linear),
            completion: -29,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: HostBoundary.value(of: journey),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        channels.follow(animator.advance(to: 50, reducesMotion: true), reducedMotion: true)
        let landed = try XCTUnwrap(channels.takeOutputs().last)

        XCTAssertEqual(landed.journey.value, [1])
        XCTAssertEqual(landed.journey.destination, [1])
        XCTAssertEqual(landed.journey.velocity, [0])
        XCTAssertEqual(landed.report, .position)
        XCTAssertEqual(
            channels.takeCompletions(),
            [JourneyCompletion(id: -29, outcome: .immediate(.reducedMotion))])
        XCTAssertFalse(channels.isActive)
    }

    @MainActor
    func testAUserTakesAnActiveJourneyAtItsOwnPosition() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 13, mode: .inOut, kind: .property, laneKind: .number)
        channels.attach(13)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(.milliseconds(200)),
            completion: -31,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: HostBoundary.value(of: journey),
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
            [JourneyCompletion(id: -31, outcome: .superseded)])
    }

    @MainActor
    func testAnOutputOnlyBindingCannotTakeItsJourney() {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 15, mode: .out, kind: .property, laneKind: .number)
        channels.attach(15)
        let journey = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(.milliseconds(200), curve: .linear),
            completion: nil,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: HostBoundary.value(of: journey),
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
        let binding = HostStateBinding(state: 17, mode: .inOut, kind: .property, laneKind: .number)
        channels.attach(17)
        let moving = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(.milliseconds(100), curve: .linear),
            completion: -41,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: HostBoundary.value(of: moving),
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
                value: HostBoundary.value(of: snapped)),
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
            [JourneyCompletion(id: -41, outcome: .superseded)])

        channels.follow(animator.advance(to: 200))
        XCTAssertTrue(channels.takeOutputs().isEmpty)
        XCTAssertTrue(channels.takeCompletions().isEmpty)
    }

    @MainActor
    func testAnAwaitedRetargetOwnsItsNewCompletion() {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 19, mode: .inOut, kind: .property, laneKind: .number)
        channels.attach(19)
        let first = HostJourney(
            value: [0],
            destination: [1],
            velocity: [0],
            motion: .eased(.milliseconds(100), curve: .linear),
            completion: -41,
            stopped: 0)
        _ = channels.presentedValue(
            for: binding,
            from: HostBoundary.value(of: first),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        let second = HostJourney(
            value: [0],
            destination: [0.25],
            velocity: [0],
            motion: .eased(.milliseconds(100), curve: .linear),
            completion: -42,
            stopped: 0)
        channels.receive(
            HostStateChange(
                state: 19,
                changed: (1 << 1) | (1 << 6),
                value: HostBoundary.value(of: second)),
            now: 50,
            reducesMotion: false)

        XCTAssertEqual(
            channels.takeCompletions(),
            [JourneyCompletion(id: -41, outcome: .superseded)])

        channels.follow(animator.advance(to: 150))
        XCTAssertEqual(
            channels.takeCompletions(),
            [JourneyCompletion(id: -42, outcome: .animated)])
    }

    /// One state is one channel however many controls wear it: it stays while any of them does, and goes when
    /// the last one leaves.
    @MainActor
    func testAChannelGoesWhenTheLastControlWearingItLeaves() {
        let runtime = HostRuntime.still()
        runtime.tree.apply(Self.labels(["a", "b"]), complete: true)
        Self.open(Self.worn, in: runtime, from: 1, to: 1)
        XCTAssertEqual(runtime.stateChannels.count, 1)

        runtime.tree.apply(Self.labels(["b"]), complete: false)
        XCTAssertEqual(runtime.stateChannels.count, 1, "the other label still wears it")

        runtime.tree.apply(Self.labels([]), complete: false)
        XCTAssertEqual(runtime.stateChannels.count, 0, "the last one took it with it")
    }

    /// A channel still moving when its last consumer leaves goes at once, its run with it, and says nothing: the
    /// core counted the same consumers and answers whoever awaited the movement.
    @MainActor
    func testAMovingChannelWhoseLastConsumerLeftGoesAtOnce() {
        let runtime = HostRuntime.still()
        runtime.tree.apply(Self.labels(["a"]), complete: true)
        Self.open(Self.worn, in: runtime, from: 0, to: 1, completion: -7)
        XCTAssertTrue(runtime.stateChannels.isActive)

        runtime.tree.apply(Self.labels([]), complete: false)

        XCTAssertEqual(runtime.stateChannels.count, 0, "no consumer, no channel")
        XCTAssertFalse(runtime.animator.isMoving, "and nothing left moving for it")
        XCTAssertEqual(runtime.stateChannels.takeCompletions(), [], "the waiter is the core's to answer")
    }

    /// A consumer that leaves one element for another in the same patch keeps the channel: it goes on from where it
    /// stands, and its waiter still waits.
    @MainActor
    func testAConsumerSwappedInOnePatchKeepsTheChannel() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(Self.labels(["a"]), complete: true)
        Self.open(Self.worn, in: runtime, from: 0, to: 1, completion: -8)
        runtime.stateChannels.follow(runtime.animator.advance(to: 100))
        _ = runtime.stateChannels.takeOutputs()

        runtime.tree.apply(Self.labels(["b"]), complete: false)

        XCTAssertEqual(runtime.stateChannels.count, 1, "the same channel")
        XCTAssertTrue(runtime.stateChannels.isActive, "still on its way")
        runtime.stateChannels.follow(runtime.animator.advance(to: 200))
        XCTAssertEqual(runtime.stateChannels.takeCompletions(), [JourneyCompletion(id: -8, outcome: .animated)])
    }

    /// A value read for a state no consumer holds opens no channel: it is the state's own.
    @MainActor
    func testAStateWithNoConsumerHasNoChannel() {
        let channels = StateChannels(animator: Animator())
        let binding = HostStateBinding(state: 41, mode: .inOut, kind: .property, laneKind: .number)
        let journey = HostJourney(
            value: [0], destination: [1], velocity: [0], motion: .eased(.milliseconds(200), curve: .linear),
            completion: nil, stopped: 0)

        let shown = channels.presentedValue(for: binding, from: HostBoundary.value(of: journey), now: 0, reducesMotion: false)

        XCTAssertEqual(shown, HostBoundary.value(of: journey))
        XCTAssertEqual(channels.count, 0)
        XCTAssertFalse(channels.isActive)
    }

    /// WHY A MOVEMENT WAS PUT AT ITS DESTINATION AT ONCE is said to its waiter: there already, a motion that does not
    /// animate, less motion asked for.
    @MainActor
    func testAnImmediateArrivalSaysWhy() {
        let channels = StateChannels(animator: Animator())
        let binding = HostStateBinding(state: 43, mode: .inOut, kind: .property, laneKind: .number)
        channels.attach(43)
        let standing = HostJourney(
            value: [0], destination: [0], velocity: [0], motion: .eased(.milliseconds(200), curve: .linear),
            completion: nil, stopped: 0)
        _ = channels.presentedValue(for: binding, from: HostBoundary.value(of: standing), now: 0, reducesMotion: false)

        func send(to destination: Double, _ motion: Motion, waiter: Int, reducesMotion: Bool = false) -> [JourneyCompletion] {
            let journey = HostJourney(
                value: [0], destination: [destination], velocity: [0], motion: motion, completion: waiter, stopped: 0)
            channels.receive(
                HostStateChange(state: 43, changed: (1 << 1) | (1 << 6), value: HostBoundary.value(of: journey)),
                now: 10, reducesMotion: reducesMotion)
            return channels.takeCompletions()
        }
        let eased = Motion.eased(.milliseconds(200), curve: .linear)

        XCTAssertEqual(send(to: 0, eased, waiter: -1), [JourneyCompletion(id: -1, outcome: .immediate(.alreadyAtDestination))])
        XCTAssertEqual(send(to: 1, .none, waiter: -2), [JourneyCompletion(id: -2, outcome: .immediate(.motionDisabled))])
        XCTAssertEqual(
            send(to: 2, eased, waiter: -3, reducesMotion: true),
            [JourneyCompletion(id: -3, outcome: .immediate(.reducedMotion))])
    }

    /// A STOP ANSWERS ITS WAITER STOPPED, and the value stands where the stop found it.
    @MainActor
    func testAStopAnswersItsWaiterStopped() throws {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let binding = HostStateBinding(state: 45, mode: .inOut, kind: .property, laneKind: .number)
        channels.attach(45)
        let moving = HostJourney(
            value: [0], destination: [1], velocity: [0], motion: .eased(.milliseconds(200), curve: .linear),
            completion: -9, stopped: 0)
        _ = channels.presentedValue(for: binding, from: HostBoundary.value(of: moving), now: 0, reducesMotion: false)
        _ = channels.takeOutputs()

        let stopped = HostJourney(
            value: [0], destination: [1], velocity: [0], motion: moving.motion, completion: -9, stopped: 1)
        channels.receive(
            HostStateChange(state: 45, changed: 1 << 7, value: HostBoundary.value(of: stopped)),
            now: 100, reducesMotion: false)

        XCTAssertEqual(channels.takeCompletions(), [JourneyCompletion(id: -9, outcome: .stopped)])
        let stood = try XCTUnwrap(channels.takeOutputs().last)
        XCTAssertEqual(stood.journey.value[0], 0.5, accuracy: 0.000_001)
        XCTAssertEqual(stood.journey.destination, stood.journey.value, "it goes nowhere from there")
        XCTAssertFalse(channels.isActive)
    }

    /// A control whose patch binds none of its properties any more lets go of every state it wore.
    @MainActor
    func testAnEmptyDrivenMapLetsItsStatesGo() throws {
        let runtime = HostRuntime.still()
        var label = HostPatch(id: .manual("label"), type: .text)
        label.driven = .replace([
            .opacity: HostStateBinding(state: Self.worn, mode: .out, kind: .property, laneKind: .number),
            .rotation: HostStateBinding(state: Self.worn + 1, mode: .out, kind: .property, laneKind: .number),
        ])
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([label])
        runtime.tree.apply(stack, complete: true)
        Self.open(Self.worn, in: runtime, from: 1, to: 1)
        Self.open(Self.worn + 1, in: runtime, from: 0, to: 0)
        XCTAssertEqual(runtime.stateChannels.count, 2)

        var unbound = HostPatch(id: .manual("label"), type: .text)
        unbound.driven = .replace([:])
        stack.children = .changed([unbound])
        runtime.tree.apply(stack, complete: false)

        XCTAssertEqual(try XCTUnwrap(runtime.tree.root?.first(id: .manual("label"))).driven, [:])
        XCTAssertEqual(runtime.stateChannels.count, 0)
    }

    /// The state the labels' opacity wears.
    private static let worn: Int32 = 801

    /// Texts under a stack, each wearing `worn` on its opacity.
    private static func labels(_ names: [String]) -> HostPatch {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged(names.map { name in
            var label = HostPatch(id: .manual(name), type: .text)
            label.driven = .replace([.opacity: HostStateBinding(state: worn, mode: .out, kind: .property, laneKind: .number)])
            return label
        })
        return stack
    }

    /// Opens the channel of `state` on a 200 ms linear journey from `value` to `destination`.
    @MainActor
    private static func open(
        _ state: Int32, in runtime: HostRuntime, from value: Double, to destination: Double, completion: Int? = nil
    ) {
        let journey = HostJourney(
            value: [value], destination: [destination], velocity: [0], motion: .eased(.milliseconds(200), curve: .linear),
            completion: completion, stopped: 0)
        _ = runtime.stateChannels.presentedValue(
            for: HostStateBinding(state: state, mode: .out, kind: .property, laneKind: .number),
            from: HostBoundary.value(of: journey),
            now: 0,
            reducesMotion: false)
    }
}
