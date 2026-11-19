// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What follows where a state is SHOWN rather than where it is going: an engine following a journey, and a reading
// of one at a rate. Each is a consumer of the state's channel while its view stands, each hears the host's frames
// and no destination written, and every sample one run reads is of one frame.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class PresentationEngineTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// AN ENGINE FOLLOWING A JOURNEY IS A CONSUMER of the state's channel while its view stands, with no property
    /// showing the state: the host is told to carry it, and told to let it go as the view leaves.
    func testAnEngineFollowingAJourneyIsAConsumer() throws {
        let x = State(wrappedValue: 0.0)
        let renders = Renders()
        let following = { stack([Text("at").engine(following: x.projectedValue.journey) { _ in }.node], id: "root") }

        XCTAssertFalse(x.storage.carried, "a handle named in a declaration carries nothing")
        let mounted = renders.render(following())
        let image = try XCTUnwrap(x.storage.image)

        XCTAssertEqual(image.consumers, 1)
        XCTAssertTrue(image.hasChannel)
        XCTAssertEqual(
            followed(in: mounted),
            [HostStateBinding(state: x.number, mode: .inOut, kind: .property, laneKind: .number)])

        let again = renders.render(following())
        XCTAssertEqual(followed(in: again), nil, "described again alike, the host is told nothing")
        XCTAssertEqual(image.consumers, 1, "and it is one consumer still")

        renders.render(stack([], id: "root"))
        XCTAssertEqual(image.consumers, 0)
        XCTAssertFalse(image.hasChannel, "the view gone, the channel went with its last consumer")
    }

    /// IT HEARS A FRAME, NOT A DESTINATION: a write of the state it follows the journey of runs it not at all; the
    /// host's word of where the value stands runs it once.
    func testItRunsOnAFrameAndNotOnADestinationWritten() {
        let x = State(wrappedValue: 0.0)
        var ran = 0
        let renders = Renders()
        renders.render(Text("at").engine(following: x.projectedValue.journey) { _ in ran += 1 }.node)
        cycle(at: 0)
        XCTAssertEqual(ran, 1, "once as its view is described")

        x.wrappedValue = 100
        cycle(at: 16)
        XCTAssertEqual(ran, 1, "a destination written is no frame")

        report(x, value: 10, destination: 100, velocity: 600, at: 32)
        cycle(at: 32)
        XCTAssertEqual(ran, 2, "the host's frame ran it")

        cycle(at: 48)
        XCTAssertEqual(ran, 2, "and nothing since")
        _ = renders
    }

    /// EVERY SAMPLE ONE RUN READS IS OF ONE FRAME: two journeys read in one run say the same time, whichever of
    /// them moved on it.
    func testTheSamplesOfOneRunAreOfOneFrame() throws {
        let (x, y) = (State(wrappedValue: 0.0), State(wrappedValue: 0.0))
        var read: [(x: JourneySample<Double>?, y: JourneySample<Double>?)] = []
        let renders = Renders()
        renders.render(
            Text("at").engine(following: x.projectedValue.journey, y.projectedValue.journey) { _ in
                read.append((x.projectedValue.journey.sample, y.projectedValue.journey.sample))
            }.node)
        cycle(at: 0)
        XCTAssertNil(read.last?.x, "nothing said yet")

        report(x, value: 3, destination: 9, velocity: 1, at: 16)
        report(y, value: 5, destination: 5, velocity: 0, at: 16)
        cycle(at: 16)
        report(x, value: 4, destination: 9, velocity: 1, at: 32)
        cycle(at: 32)

        let last = try XCTUnwrap(read.last)
        XCTAssertEqual(last.x?.value, 4)
        XCTAssertEqual(last.y?.value, 5, "the one standing still is read where it stands")
        XCTAssertEqual(last.x?.time, .milliseconds(32))
        XCTAssertEqual(last.y?.time, last.x?.time, "both of the frame the run reads on")
        _ = renders
    }

    /// ITS OWN SNAP WAKES IT NOT: an engine that lands an output where the sample says is not run again by that
    /// write, nor does the write move the sample it read.
    func testAnEngineLandingItsOutputIsNotWokenByIt() {
        let (x, shown) = (State(wrappedValue: 0.0), State(wrappedValue: 0.0))
        var ran = 0
        let renders = Renders()
        renders.render(VStack {
            Rectangle().translationX(shown.projectedValue)
            Text("at").engine(following: x.projectedValue.journey) { _ in
                ran += 1
                if let sample = x.projectedValue.journey.sample { shown.projectedValue.journey.snap(to: sample.value) }
            }
        }.node)
        cycle(at: 0)

        report(x, value: 7, destination: 9, velocity: 1, at: 16)
        cycle(at: 16)
        cycle(at: 32)

        XCTAssertEqual(ran, 2, "once described, once for the frame")
        XCTAssertEqual(shown.wrappedValue, 7)
        XCTAssertEqual(x.projectedValue.journey.sample?.value, 7)
        _ = renders
    }

    // MARK: - Readings

    /// A READING IS TAKEN ON THE DISPLAY'S FRAMES: the first sample at once, one inside the window on the first
    /// frame at or past the window's end - what stands then - and the clock is held until it is.
    func testAReadingIsTakenOnTheFramesByTheirTime() {
        let (fade, shown) = (State(wrappedValue: 1.0), State(wrappedValue: 1.0))
        let renders = Renders()
        renders.render(reading(fade, into: shown, every: 100))
        cycle(at: 0)

        report(fade, value: 0.9, destination: 0, velocity: -1, at: 10)
        XCTAssertEqual(shown.wrappedValue, 0.9, "the first sample is read at once")

        report(fade, value: 0.8, destination: 0, velocity: -1, at: 20)
        XCTAssertEqual(shown.wrappedValue, 0.9, "one inside the window waits for its end")
        XCTAssertTrue(Renderer.shared.cycleAwake(), "and holds the clock until then")

        report(fade, value: 0.7, destination: 0, velocity: -1, at: 60)
        cycle(at: 60)
        XCTAssertEqual(shown.wrappedValue, 0.9, "not yet")

        cycle(at: 110)
        XCTAssertEqual(shown.wrappedValue, 0.7, "the window ended: what stands then is read")
        cycle(at: 126)
        XCTAssertFalse(Renderer.shared.cycleAwake(), "and nothing holds the clock with no sample to deliver")
        _ = renders
    }

    /// A READING IS A CONSUMER, and its leaving takes the booked reading with it: nothing is read after.
    func testAReadingGoneIsNeverTaken() throws {
        let (fade, shown) = (State(wrappedValue: 1.0), State(wrappedValue: 1.0))
        let renders = Renders()
        renders.render(stack([reading(fade, into: shown, every: 100)], id: "root"))
        let image = try XCTUnwrap(fade.storage.image)
        XCTAssertEqual(image.consumers, 2, "the box showing it and the reading of it")
        cycle(at: 0)

        report(fade, value: 0.9, destination: 0, velocity: -1, at: 10)
        report(fade, value: 0.8, destination: 0, velocity: -1, at: 20)
        renders.render(stack([Rectangle().opacity(fade.projectedValue).node], id: "root"))
        XCTAssertEqual(image.consumers, 1, "the reading let its lease go")

        cycle(at: 200)
        XCTAssertEqual(shown.wrappedValue, 0.9, "the reading booked went with its element")
        XCTAssertFalse(Renderer.shared.cycleAwake())
    }

    /// A READING WRITTEN ON A COMPOSED VIEW is a consumer as one written on a control is.
    func testAReadingOnAComposedViewIsAConsumer() throws {
        let (fade, shown) = (State(wrappedValue: 1.0), State(wrappedValue: 1.0))
        let renders = Renders()
        renders.render(
            Caption(words: "shown")
                .samples(fade.projectedValue.journey, into: shown.projectedValue, .always).node)

        XCTAssertEqual(try XCTUnwrap(fade.storage.image).consumers, 1)
        XCTAssertTrue(try XCTUnwrap(fade.storage.image).hasChannel)
        _ = renders
    }

    /// A REBUILD KEEPS THE WINDOW: the reading's own write renders its view again, and the standing reading at the
    /// same rate goes on counting from the frame it last read on.
    func testARebuildKeepsTheReadingsWindow() {
        let (fade, shown) = (State(wrappedValue: 1.0), State(wrappedValue: 1.0))
        let renders = Renders()
        renders.render(reading(fade, into: shown, every: 100))
        cycle(at: 0)
        report(fade, value: 0.9, destination: 0, velocity: -1, at: 10)

        renders.render(reading(fade, into: shown, every: 100))
        report(fade, value: 0.8, destination: 0, velocity: -1, at: 20)

        XCTAssertEqual(shown.wrappedValue, 0.9, "built again, the window stands")
        _ = renders
    }

    /// TWO FRAMES INSIDE ONE WINDOW TAKE ONE READING: the first at once, the second booking one for the window's
    /// end, a third covered by the booking; past the window a frame is read at once and starts the next from itself.
    func testAReadingsWindowByTheFramesTime() {
        let sampling = Sampling(window: 100, take: {})

        XCTAssertEqual(sampling.due(at: 1000), .now, "the first frame is read at once")
        XCTAssertEqual(sampling.due(at: 1010), .waitUntil(1100), "the second books one for the window's end")
        XCTAssertEqual(sampling.due(at: 1020), .waiting, "the third is covered by the booking standing")
        XCTAssertFalse(sampling.takeBooked(at: 1099), "not before its time")
        XCTAssertTrue(sampling.takeBooked(at: 1101))
        XCTAssertEqual(sampling.due(at: 1150), .waitUntil(1201), "the next window runs from the reading taken")
    }

    /// One value's readings are taken in the order they were asked for, every time.
    func testAValuesReadingsAreTakenInTheOrderAsked() {
        let storage = HostStorage(StateImage.bytes(of: JourneyLanes(0.0).carried))
        let targets = (0..<8).map { _ in State(0.0) }
        var taken: [Int] = []

        let readings = targets.enumerated().map { index, target in
            storage.sample(into: ObjectIdentifier(target.storage), every: 0) { taken.append(index) }
        }
        storage.sampleTaken(at: 0)

        withExtendedLifetime(readings) { XCTAssertEqual(taken, Array(0..<8)) }
    }

    /// A READING INTO ITS OWN SOURCE IS REFUSED, said once: it would feed itself.
    func testAReadingIntoItsOwnSourceIsRefused() throws {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()
        renders.render(
            Rectangle().opacity(fade.projectedValue)
                .samples(fade.projectedValue.journey, into: fade.projectedValue, .always).node)

        XCTAssertEqual(try XCTUnwrap(fade.storage.image).consumers, 1, "the box alone: no reading was asked for")
        XCTAssertTrue(Said.shared.said("would feed the reading its own writes"))
    }

    // MARK: - The bench

    /// A box showing `source`, read into `target` at most once every `window` milliseconds.
    private func reading(_ source: State<Double>, into target: State<Double>, every window: Int) -> Node {
        Rectangle().opacity(source.projectedValue)
            .samples(source.projectedValue.journey, into: target.projectedValue, .every(.milliseconds(window))).node
    }

    /// The states an element of `patch` is told it follows the journey of; nil where no element is told.
    private func followed(in patch: HostPatch) -> [HostStateBinding]? {
        if case .replace(let followed)? = patch.followed { return followed }

        return patch.children.lazy.compactMap { self.followed(in: $0) }.first
    }

    /// Runs the display's cycle at `time`.
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

/// A composed view of one caption.
private struct Caption: View {
    let words: String

    var body: some View { Text(words) }
}
