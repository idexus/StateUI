// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A channel's life: a state has a destination with no host at all, and a sample only while something shows it.
//
// The handle - `$x.journey` - owns nothing and starts nothing. A channel opens with a state's first consumer,
// closes with its last, and what stands between two channels is the destination alone: no speed, no place on
// the way, no waiter left waiting.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class ChannelLifetimeTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// NO RECEIVER: a state nothing shows has its value and no sample; a move writes the destination and says no
    /// movement was made.
    func testAStateNothingShowsHasADestinationAndNoSample() {
        let fade = State(wrappedValue: 1.0)
        let journey = fade.projectedValue.journey

        XCTAssertNil(journey.sample, "nothing shows it")
        XCTAssertNil(journey.reach(.glide(longest: .milliseconds(800))), "and nothing carries it anywhere")

        let run = journey.move(to: 0.25, .eased(.milliseconds(400)))

        XCTAssertEqual(run.outcome, .notStarted(.noReceiver))
        XCTAssertEqual(fade.wrappedValue, 0.25, "the destination was written all the same")
        XCTAssertNil(journey.sample)

        journey.stop()
        XCTAssertEqual(fade.wrappedValue, 0.25, "a stop of nothing changes nothing")

        journey.snap(to: 0.5)
        XCTAssertEqual(fade.wrappedValue, 0.5, "and a snap is a plain write")
    }

    /// A HANDLE STARTS NOTHING: a thousand states, bindings and journeys read make no image, no number and no
    /// work for the clock.
    func testAThousandHandlesMakeNoChannel() {
        let board = Renderer.shared.board
        board.cycle(now: 0, reducesMotion: false)
        var states: [State<Double>] = []

        for index in 0..<1000 {
            let state = State(wrappedValue: Double(index))
            let journey = state.projectedValue.journey
            _ = journey.sample
            _ = journey.motion
            _ = journey.reach(.spring())
            journey.stop()
            states.append(state)
        }

        XCTAssertTrue(states.allSatisfy { !$0.storage.carried }, "a read of the handle carried a state")
        XCTAssertFalse(Renderer.shared.cycleAwake(), "and nothing waits for a cycle")
        XCTAssertFalse(Renderer.shared.cycleAsked())
    }

    /// THE FIRST CONSUMER opens the channel where the destination stands, still: writes made before anything showed
    /// the state are not replayed, and the sample comes with the host's first word.
    func testTheFirstConsumerStartsAtTheDestinationStill() throws {
        let fade = State(wrappedValue: 1.0)
        let journey = fade.projectedValue.journey
        fade.wrappedValue = 0.2
        fade.wrappedValue = 0.6

        Renders().render(Rectangle().opacity(fade.projectedValue).node)
        XCTAssertNil(journey.sample, "the host has said nothing yet")

        let (_, handed) = try XCTUnwrap(HostAnimatorReport.standing(fade.number))
        XCTAssertEqual(handed.value, [0.6], "the channel starts where the state is")
        XCTAssertEqual(handed.destination, [0.6])
        XCTAssertEqual(handed.velocity, [0])

        report(fade, value: 0.6, destination: 0.6, velocity: 0, at: 16)
        XCTAssertEqual(journey.sample, JourneySample(value: 0.6, destination: 0.6, velocity: 0, time: .milliseconds(16)))
    }

    /// A SAMPLE IS THE HOST'S WORD OF ONE FRAME: a destination written since is the state's own value, and the
    /// sample goes on saying where the channel was taking the value on the frame it speaks of.
    func testASampleIsOfOneFrame() {
        let fade = State(wrappedValue: 1.0)
        let journey = fade.projectedValue.journey
        Renders().render(Rectangle().opacity(fade.projectedValue).node)

        fade.wrappedValue = 0.5
        cycle(at: 16)
        report(fade, value: 0.75, destination: 0.5, velocity: -1.5, at: 32)
        fade.wrappedValue = 0

        XCTAssertEqual(fade.wrappedValue, 0, "the state holds the newer destination")
        XCTAssertEqual(
            journey.sample, JourneySample(value: 0.75, destination: 0.5, velocity: -1.5, time: .milliseconds(32)),
            "the sample is still the frame the host reported, whole")
    }

    /// THE LAST CONSUMER GONE ends the channel: the sample goes, a movement under way answers `.detached`, and the
    /// state stands at its destination.
    func testTheLastConsumerGoneEndsTheRunDetached() {
        let fade = State(wrappedValue: 1.0)
        let journey = fade.projectedValue.journey
        let renders = Renders()
        renders.render(stack([Rectangle().opacity(fade.projectedValue).node], id: "root"))
        report(fade, value: 1, destination: 1, velocity: 0, at: 0)

        let run = journey.move(to: 0, .eased(.seconds(1)))
        XCTAssertNil(run.outcome, "shown, it waits for the host")
        report(fade, value: 0.5, destination: 0, velocity: -1, at: 500)

        renders.render(stack([], id: "root"))

        XCTAssertEqual(run.outcome, .detached)
        XCTAssertNil(journey.sample, "no channel, no sample")
        XCTAssertEqual(fade.wrappedValue, 0, "the destination stands")
        XCTAssertEqual(journey.move(to: 1).outcome, .notStarted(.noReceiver))
    }

    /// ATTACHED AGAIN, a state has a channel of a new generation that starts at the destination, still: nothing of
    /// the speed or the place the last one stood at comes back.
    func testAttachedAgainItStartsStill() throws {
        let fade = State(wrappedValue: 1.0)
        let journey = fade.projectedValue.journey
        let renders = Renders()
        let shown = { stack([Rectangle().opacity(fade.projectedValue).node], id: "root") }
        renders.render(shown())
        let image = try XCTUnwrap(fade.storage.image)
        let first = image.generation

        journey.move(to: 0, .eased(.seconds(1)))
        cycle(at: 16)
        report(fade, value: 0.5, destination: 0, velocity: -1, at: 500)
        renders.render(stack([], id: "root"))
        renders.render(shown())
        cycle(at: 516)

        XCTAssertEqual(image.generation, first + 1, "a channel of a new generation")
        XCTAssertNil(journey.sample, "which has said nothing yet")
        let (_, handed) = try XCTUnwrap(HostAnimatorReport.standing(fade.number))
        XCTAssertEqual(handed.value, [0], "it starts at the destination")
        XCTAssertEqual(handed.velocity, [0], "standing still")
        XCTAssertNil(handed.completion, "with no waiter of the channel before")
    }

    /// TAKEN OVER IN ONE WALK: a consumer that leaves one element for another in the same render never ends the
    /// channel - the same generation, the sample standing, the movement still waited on.
    func testAConsumerSwappedInOneWalkKeepsTheChannel() throws {
        let fade = State(wrappedValue: 1.0)
        let journey = fade.projectedValue.journey
        let renders = Renders()
        let worn = { Rectangle().opacity(fade.projectedValue).node }
        renders.render(stack([stack([worn()], id: "a"), stack([], id: "b")], id: "root"))
        let image = try XCTUnwrap(fade.storage.image)
        let generation = image.generation

        let run = journey.move(to: 0, .eased(.seconds(1)))
        report(fade, value: 0.5, destination: 0, velocity: -1, at: 500)
        renders.render(stack([stack([], id: "a"), stack([worn()], id: "b")], id: "root"))

        XCTAssertNil(run.outcome, "shown again in the same walk, it is still walked")
        XCTAssertEqual(image.generation, generation, "the same channel")
        XCTAssertEqual(journey.sample?.value, 0.5, "and its sample stands")
    }

    /// ONE OF SEVERAL LEAVES and the rest go on: the channel is its consumers' together.
    func testOneOfSeveralConsumersLeavingChangesNothing() throws {
        let fade = State(wrappedValue: 1.0)
        let journey = fade.projectedValue.journey
        let renders = Renders()
        let worn = { Rectangle().opacity(fade.projectedValue).node }
        renders.render(stack([stack([worn()], id: "a"), stack([worn()], id: "b")], id: "root"))

        let run = journey.move(to: 0, .eased(.seconds(1)))
        report(fade, value: 0.5, destination: 0, velocity: -1, at: 500)
        renders.render(stack([stack([], id: "a"), stack([worn()], id: "b")], id: "root"))

        XCTAssertNil(run.outcome)
        XCTAssertEqual(journey.sample?.value, 0.5)
    }

    /// A FRAME IS NO WRITE OF THE STATE: an engine following the state hears a destination written - an equal one
    /// too - and not a frame of where the host shows it; one following the journey hears the frame.
    func testAFrameMovesTheSampleAndNotTheStatesStamp() {
        let fade = State(wrappedValue: 1.0)
        Renders().render(Rectangle().opacity(fade.projectedValue).node)
        let (storage, watch) = (fade.storage, fade.storage.presentation)
        report(fade, value: 1, destination: 1, velocity: 0, at: 0)

        let (written, shown) = (storage.stamp, watch.stamp)
        report(fade, value: 0.9, destination: 1, velocity: -1, at: 16)
        XCTAssertEqual(storage.stamp, written, "a frame wrote the state")
        XCTAssertNotEqual(watch.stamp, shown, "a frame left the sample's followers asleep")

        let framed = watch.stamp
        fade.wrappedValue = 1
        XCTAssertNotEqual(storage.stamp, written, "an equal destination written is still a write")
        XCTAssertEqual(watch.stamp, framed, "and a write is no frame")
    }

    /// A BODY THAT READ THE SAMPLE is asked when the sample changes, comes or goes - and never for a destination
    /// written, which a body reading the state is asked for.
    func testABodyReadingTheSampleIsAskedAsItChanges() {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()
        renders.render(stack([Rectangle().opacity(fade.projectedValue).node], id: "root"))
        let reader = reading { _ = fade.projectedValue.journey.sample }
        Renderer.shared.clearInvalidation()

        report(fade, value: 1, destination: 1, velocity: 0, at: 0)
        XCTAssertTrue(Renderer.shared.needsRender, "the sample came")
        Renderer.shared.clearInvalidation()

        report(fade, value: 1, destination: 1, velocity: 0, at: 16)
        XCTAssertFalse(Renderer.shared.needsRender, "the same sample again asks nothing")

        renders.render(stack([], id: "root"))
        XCTAssertTrue(Renderer.shared.needsRender, "the sample went")
        _ = reader
    }

    /// Runs the display's cycle at `time`, which publishes what was written since the last.
    private func cycle(at time: Double) {
        Renderer.shared.board.cycle(now: time, reducesMotion: false)
    }

    /// Reports where the host's channel of `state` stands on the frame at `time`.
    private func report(
        _ state: State<Double>, value: Double, destination: Double, velocity: Double, at time: Double,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let (binding, standing) = HostAnimatorReport.standing(state.number) else {
            return XCTFail("the host carries no journey of that state", file: file, line: line)
        }

        let journey = HostJourney(
            value: [value], destination: [destination], velocity: [velocity], motion: standing.motion,
            completion: standing.completion, stopped: standing.stopped)
        XCTAssertTrue(
            HostBoundary.report(journey, updating: .frame, through: binding, at: time), "the report was refused",
            file: file, line: line)
    }
}
