// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The engine that animates a state: one animator a state, a token good for one call, a movement that ends when
// the engine says so and is answered once the host has shown the frame.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class EngineMotionTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// AN ENGINE WALKS ITS STATE TO WHERE IT IS SENT: frame by frame it says where the value stands, the host is
    /// handed each frame at once, and the movement is answered `.reached(.animated)` as the engine finishes - by
    /// the host, once it has the frame.
    func testAnEngineWalksItsStateAndTheMovementEndsWhenItFinishes() throws {
        let handle = Handle()
        let renders = Renders()
        renders.render(Dot(handle: handle).node)
        let offset = try XCTUnwrap(handle.offset)
        cycle(at: 0)

        let run = offset.journey.move(to: 120)
        XCTAssertNil(run.outcome, "handed to the engine, it waits for the engine's word")
        XCTAssertEqual(offset.wrappedValue, 120, "the destination is the state's at once")

        var answered: [HostFinishedMotion] = []
        var samples: [Double] = []
        for frame in 1...200 where run.outcome == nil {
            answered += cycle(at: Double(frame) * 16)
            if let sample = offset.journey.sample { samples.append(sample.value) }
            let crossed = try XCTUnwrap(offset.journeyImage?.number.flatMap(Renderer.shared.board.whole))
            XCTAssertEqual(
                StateImage.lane(0, of: crossed), StateImage.lane(1, of: crossed),
                "the host is handed the engine's frame as where the value is going")
            if !answered.isEmpty { answered.forEach { HostBoundary.complete($0.completion, as: $0.outcome) } }
        }

        XCTAssertEqual(run.outcome, .reached(.animated))
        XCTAssertEqual(answered.count, 1, "answered once")
        XCTAssertTrue(samples.contains { $0 > 0 && $0 < 120 }, "the frames between were the journey's samples")
        XCTAssertEqual(offset.journey.sample?.value, 120)
        XCTAssertEqual(offset.journey.sample?.velocity, 0)
        _ = renders
    }

    /// A NEWER DESTINATION SUPERSEDES; A STOP STOPS; THE ENGINE GONE DETACHES: each movement handed over hears one
    /// word.
    func testAMovementHandedToTheEngineEndsOnce() throws {
        let handle = Handle()
        let renders = Renders()
        renders.render(stack([Dot(handle: handle).node], id: "root"))
        let offset = try XCTUnwrap(handle.offset)
        cycle(at: 0)

        let first = offset.journey.move(to: 100)
        let second = offset.journey.move(to: 50)
        XCTAssertEqual(first.outcome, .superseded, "a newer destination took it")

        cycle(at: 16)
        offset.journey.stop()
        XCTAssertEqual(second.outcome, .stopped)
        XCTAssertEqual(offset.wrappedValue, offset.journey.sample?.value, "stopped, it goes nowhere from there")

        let third = offset.journey.move(to: 10)
        offset.wrappedValue = 20
        XCTAssertEqual(third.outcome, .superseded, "a plain write is a newer destination too")

        let fourth = offset.journey.move(to: 30)
        renders.render(stack([], id: "root"))
        XCTAssertEqual(fourth.outcome, .detached, "its animator and its last consumer left")
    }

    /// AN ENGINE'S STATE TAKES NO MOTION: a move naming one is refused before anything is written, and so is
    /// `setMotion`.
    func testAnEnginesStateTakesNoMotion() throws {
        let handle = Handle()
        let renders = Renders()
        renders.render(Dot(handle: handle).node)
        let offset = try XCTUnwrap(handle.offset)

        XCTAssertEqual(offset.journey.move(to: 40, .spring()).outcome, .notStarted(.incompatibleAnimator))
        XCTAssertEqual(offset.wrappedValue, 0, "nothing was written")
        XCTAssertNil(offset.journey.motion)
        XCTAssertThrowsError(try offset.journey.setMotion(.spring()))
        _ = renders
    }

    /// NO ANIMATOR REGISTERED: a state declared for an engine and shown with none takes its destination and shows
    /// it at once, and the movement says why nothing moved.
    func testWithNoAnimatorTheDestinationIsShownAtOnce() throws {
        let ball = State(wrappedValue: 0.0, animatedBy: .engine)
        let renders = Renders()
        renders.render(Rectangle().translationY(ball.projectedValue).node)
        cycle(at: 0)

        let run = ball.projectedValue.journey.move(to: 50)

        XCTAssertEqual(run.outcome, .notStarted(.noAnimator))
        XCTAssertEqual(ball.wrappedValue, 50)
        cycle(at: 16)
        let crossed = try XCTUnwrap(Renderer.shared.board.whole(ball.number))
        XCTAssertEqual(StateImage.lane(0, of: crossed), 50, "the host is handed the destination as where it stands")
        XCTAssertTrue(Said.shared.said("no `engine(animating:)` is registered"))
        _ = renders
    }

    /// ONE STATE, ONE ANIMATOR: a second is refused, naming both places, and never runs.
    func testASecondAnimatorIsRefused() {
        let ball = State(wrappedValue: 0.0, animatedBy: .engine)
        var ran = (first: 0, second: 0)
        let renders = Renders()
        renders.render(VStack {
            Rectangle().translationY(ball.projectedValue)
                .engine(animating: ball.projectedValue) { _, motion in ran.first += 1; motion.finish(); return .wait }
                .id("first")
            Rectangle()
                .engine(animating: ball.projectedValue) { _, motion in ran.second += 1; motion.finish(); return .wait }
                .id("second")
        }.node)
        cycle(at: 0)

        XCTAssertEqual(ran.first, 1)
        XCTAssertEqual(ran.second, 0, "the second animator ran")
        XCTAssertTrue(Said.shared.said("A state has one animator"))
        _ = renders
    }

    /// A STATE THE HOST ANIMATES TAKES NO ANIMATOR: `engine(animating:)` is for `@State(animatedBy: .engine)`.
    func testAnAnimatorOfAStateTheHostAnimatesIsRefused() {
        let fade = State(wrappedValue: 1.0)
        var ran = 0
        let renders = Renders()
        renders.render(
            Rectangle().opacity(fade.projectedValue)
                .engine(animating: fade.projectedValue) { _, _ in ran += 1; return .wait }.node)
        cycle(at: 0)

        XCTAssertEqual(ran, 0)
        XCTAssertTrue(Said.shared.said("Declare it `@State(animatedBy: .engine)`"))
        _ = renders
    }

    /// A TOKEN IS GOOD FOR ITS CALL ALONE: kept, it writes nothing on a later frame.
    func testATokenKeptPastItsCallWritesNothing() throws {
        let ball = State(wrappedValue: 0.0, animatedBy: .engine)
        var kept: EngineMotion<Double>?
        let renders = Renders()
        renders.render(
            Rectangle().translationY(ball.projectedValue)
                .engine(animating: ball.projectedValue) { _, motion in
                    kept = motion
                    return .wait
                }.node)
        cycle(at: 0)

        let stale = try XCTUnwrap(kept)
        stale.update(value: 77, velocity: 5)
        stale.finish()

        XCTAssertEqual(stale.value, 0, "a kept token moved the value")
        cycle(at: 16)
        XCTAssertNil(ball.projectedValue.journey.sample, "and offered no sample")
        _ = renders
    }

    /// LESS MOTION ASKED FOR lands the value for the engine: the author's arithmetic is not run, and the movement
    /// says why it arrived at once.
    func testReducedMotionLandsItAboveTheAnimator() throws {
        let handle = Handle()
        let renders = Renders()
        renders.render(Dot(handle: handle).node)
        let offset = try XCTUnwrap(handle.offset)
        cycle(at: 0)
        let ranBefore = handle.ran

        let run = offset.journey.move(to: 90)
        let answered = cycle(at: 16, reducesMotion: true)
        answered.forEach { HostBoundary.complete($0.completion, as: $0.outcome) }

        XCTAssertEqual(run.outcome, .reached(.immediate(.reducedMotion)))
        XCTAssertEqual(offset.journey.sample?.value, 90)
        XCTAssertEqual(handle.ran, ranBefore, "the author's arithmetic ran with less motion asked for")
        _ = renders
    }

    /// `.wait` IS NO ARRIVAL: an engine that waits without finishing leaves the movement open.
    func testWaitingIsNotFinishing() {
        let ball = State(wrappedValue: 0.0, animatedBy: .engine)
        let renders = Renders()
        renders.render(
            Rectangle().translationY(ball.projectedValue)
                .engine(animating: ball.projectedValue) { _, motion in
                    motion.update(value: motion.value + 1, velocity: 0)
                    return .wait
                }.node)
        cycle(at: 0)

        let run = ball.projectedValue.journey.move(to: 10)
        for frame in 1...5 { cycle(at: Double(frame) * 16).forEach { HostBoundary.complete($0.completion, as: $0.outcome) } }

        XCTAssertNil(run.outcome, "the engine waits for its next input: it never said it arrived")
        _ = renders
    }

    /// Runs the display's cycle at `time`, as the host does, and answers what an engine finished in it.
    @discardableResult
    private func cycle(at time: Double, reducesMotion: Bool = false) -> [HostFinishedMotion] {
        HostBoundary.cycle(now: time, reducesMotion: reducesMotion).finished
    }
}

/// Where the dot's state is lent out to the test, and how often its arithmetic ran.
@MainActor
private final class Handle {
    var offset: Binding<Double>?
    var ran = 0
}

/// A dot an engine of its own springs to where its state is sent.
private struct Dot: View {
    @State(animatedBy: .engine) private var offset = 0.0
    let handle: Handle

    var body: some View {
        handle.offset = $offset
        return Rectangle()
            .translationX($offset)
            .engine(animating: $offset) { cycle, motion in
                handle.ran += 1
                let seconds = cycle.elapsedSeconds
                let pull = (motion.destination - motion.value) * 180 - motion.velocity * 12
                let velocity = motion.velocity + pull * seconds
                let value = motion.value + velocity * seconds
                guard abs(motion.destination - value) > 0.5 || abs(velocity) > 1 else {
                    motion.finish()
                    return .wait
                }
                motion.update(value: value, velocity: velocity)
                return .again
            }
    }
}
