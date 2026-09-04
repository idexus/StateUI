// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The cycle: read, work out, write - and every rule that makes running it
// twice over one image answer the same bytes.
//
// Nothing here needs a host. The board is handed an instant and asked for a
// cycle, exactly as `stateui_cycle_run` will hand it one, so every number
// below is exact and none of it depends on a frame ever arriving.

import XCTest
@testable import StateUI

/// What each engine did, kept in a class so the state walk leaves it alone.
private final class Ran {
    var order: [String] = []
    var elapsed: [String: [Double]] = [:]

    func note(_ name: String, _ cycle: EngineCycle) {
        order.append(name)
        elapsed[name, default: []].append(cycle.elapsed)
    }
}

/// A view with one engine over one driven state, which is the smallest thing
/// that can be asked to run.
private struct Doubler: ContentView {
    @Bus var input = 0.0
    @Bus var output = 0.0
    let ran: Ran

    var content: Element {
        Label("doubler").engine(following: $input) { cycle in
            ran.note("doubler", cycle)
            output = input * 2
        }
    }
}

/// Two engines on one view, written in the order the LOWER priority is second
/// - so a test can see that the order run is the priority's and not the
/// source's.
private struct Ordered: ContentView {
    @Bus var value = 0.0
    let ran: Ran

    var content: Element {
        Label("ordered")
            .engine(following: $value, priority: 10) { cycle in ran.note("late", cycle) }
            .engine(following: $value, priority: 1) { cycle in ran.note("early", cycle) }
    }
}

/// An engine with nothing to follow, which runs on its own answer alone.
private struct Ticking: ContentView {
    @Bus var count = 0.0
    let ran: Ran
    let stopAfter: Int

    var content: Element {
        Label("ticking").engine { cycle in
            ran.note("ticking", cycle)
            count += 1
            return Int(count) >= stopAfter ? .idle : .running
        }
    }
}

/// An engine that switches on an `@EngineState` - which it therefore follows,
/// though nothing says so anywhere.
private struct Switching: ContentView {
    @EngineState var step = 0
    @Bus var seen = 0.0
    let ran: Ran

    var content: Element {
        Label("switching").engine { cycle in
            ran.note("switching", cycle)
            seen = Double(step)
            return .idle
        }
    }
}

/// A sequence: three steps, each leaving on a condition of its own, which is
/// what an engine that has to do one thing and then another looks like.
private struct Sequencing: ContentView {
    enum Step { case waiting, running, done }

    @EngineState var phase = Phase(Step.waiting)
    @Bus var progress = 0.0
    let ran: Ran

    var content: Element {
        Label("sequencing").engine { cycle in
            ran.note("sequencing", cycle)

            switch phase.current {
            case .waiting where phase.elapsed(cycle) >= 50:
                phase.go(to: .running)
            case .running where phase.elapsed(cycle) >= 100:
                phase.go(to: .done)
            case .running:
                progress = phase.elapsed(cycle)
            default:
                break
            }

            return phase.current == .done ? .idle : .running
        }
    }
}

/// A view with two states: one its BODY shows, one only its ENGINE reads - and
/// a driven state to follow that never moves, so the only thing that can make
/// the engine run again is a render arming it.
private struct Quiet: ContentView {
    @State var shown = 0
    @State var hidden = 1.0
    @Bus var idle = 0.0
    @Bus var output = 0.0
    let ran: Ran

    var content: Element {
        Label("\(shown)").engine(following: $idle) { cycle in
            ran.note("quiet", cycle)
            output = hidden
        }
    }
}

final class CycleTests: XCTestCase {
    private var board: CycleBoard { Renderer.shared.board(for: .display) }

    /// A cycle at an instant, for arithmetic that needs one and nothing else.
    private func cycle(at now: Double) -> EngineCycle {
        EngineCycle(sync: .display, now: now, elapsed: 16, count: 1, reducesMotion: false)
    }

    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    // MARK: - The image

    /// Every value that can ride a number goes onto the image and comes back the
    /// same - which is the whole of what a `StateValue` promises.
    func testEveryStateValueRoundTrips() {
        func trip<Value: StateValue>(_ value: Value, _ file: StaticString = #filePath, _ line: UInt = #line) {
            let bytes = StateImage.bytes(of: value.carried)
            let back = Value(carried: StateImage.carried(of: bytes, lanes: Value.lanes))

            XCTAssertEqual(back, value, "\(Value.self)", file: file, line: line)
        }

        trip(1.5)
        trip(-0.0)
        trip(42)
        trip(true)
        trip(false)
        trip(Point(x: 3, y: -4))
        trip(Rect(1, 2, 3, 4))
        trip(Thickness(1, 2, 3, 4))
        trip(Color("#8040C0FF"))
        trip("a caption, ż and 漢")
        trip("")
    }

    /// A write is compared BIT FOR BIT, so the two numbers a comparison by
    /// value gets wrong are answered right: minus nought is not nought, and a
    /// NaN is itself.
    func testAWriteIsComparedBitForBit() {
        var slot = StateImage.bytes(of: StateCarried.lanes([0]))

        XCTAssertEqual(
            HostStorage.lay(StateImage.bytes(of: .lanes([-0.0])), into: &slot), 1,
            "minus nought is a different number to write")

        XCTAssertEqual(
            HostStorage.lay(StateImage.bytes(of: .lanes([-0.0])), into: &slot), 0,
            "and writing it again is no write at all")

        slot = StateImage.bytes(of: .lanes([Double.nan]))

        XCTAssertEqual(
            HostStorage.lay(StateImage.bytes(of: .lanes([Double.nan])), into: &slot), 0,
            "a NaN is the same bits as itself, whatever == says about it")
    }

    /// Dirt is per LANE: a rectangle whose width moved says so about the width
    /// and about nothing else.
    func testDirtIsPerLane() {
        var slot = StateImage.bytes(of: Rect(0, 0, 10, 10).carried)

        XCTAssertEqual(
            HostStorage.lay(StateImage.bytes(of: Rect(0, 0, 20, 10).carried), into: &slot),
            1 << 2)

        XCTAssertEqual(
            HostStorage.lay(StateImage.bytes(of: Rect(5, 0, 20, 10).carried), into: &slot),
            1 << 0)
    }

    /// A write made while no cycle is running is read back at once by whoever
    /// made it - the image is what the program sees - and reaches the CYCLE at
    /// its next latch.
    func testAWriteOutsideACycleIsReadBackAndLatched() {
        let value = Bus(wrappedValue: 0.0)

        value.wrappedValue = 7

        XCTAssertEqual(value.wrappedValue, 7, "the writer reads what it wrote")

        let report = board.cycle(now: 0, reducesMotion: false)

        XCTAssertEqual(report.latched, 1)
        XCTAssertEqual(value.wrappedValue, 7)
    }

    // MARK: - The cycle

    /// The first cycle of all LATCHES ONLY. There is no elapsed time anybody
    /// could act on before it, and an engine handed one would be handed the
    /// age of the process.
    func testTheFirstCycleLatchesOnly() throws {
        let ran = Ran()
        let renders = Renders()

        renders.render(Doubler(ran: ran).body)

        board.cycle(now: 0, reducesMotion: false)
        XCTAssertEqual(ran.order, [], "nothing runs on the cycle that starts the clock")

        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order, ["doubler"], "and everything armed runs on the next")
    }

    /// So does the first cycle after a SILENCE: an application that was asleep
    /// has a pile of writes and a gap no arithmetic should be handed.
    func testACycleAfterASilenceLatchesOnly() {
        let ran = Ran()
        let renders = Renders()
        let view = Doubler(ran: ran)

        renders.render(view.body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1)

        // Written while the application was away, which is a reason to run -
        // and the cycle that comes back still runs nothing.
        view.input = 5
        let latching = board.cycle(now: 5_000, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 1, "the cycle after the gap latches only")
        XCTAssertEqual(view.output, 0)

        // AND IT ASKS FOR THE NEXT ONE. Nothing ran, so everything the silence
        // piled up is still waiting - and with no frame asked for, what was
        // just latched would sit in the image until something else happened to
        // wake the display.
        XCTAssertTrue(latching.awake, "a latching cycle has more to do")

        board.cycle(now: 5_016, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 2, "and the one after it runs over what was latched")
        XCTAssertEqual(view.output, 10)
        XCTAssertEqual(ran.elapsed["doubler"]?.last, 16)
    }

    /// Engines run in ascending PRIORITY, whatever order they were written in
    /// - which is what lets one read what another wrote in the same cycle.
    func testEnginesRunInPriorityOrder() {
        let ran = Ran()
        let renders = Renders()

        renders.render(Ordered(ran: ran).body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(ran.order, ["early", "late"])
    }

    /// An engine whose states have not moved does not run - which is what makes
    /// a still page cost nothing.
    func testAnEngineIsSkippedWhileNothingItFollowsMoves() {
        let ran = Ran()
        let renders = Renders()
        let view = Doubler(ran: ran)

        renders.render(view.body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 1, "the render armed it once")

        let report = board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 1)
        XCTAssertEqual(report.skipped, 1)

        view.input = 21
        board.cycle(now: 48, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 2, "and a written state is a reason to run")
        XCTAssertEqual(view.output, 42)
    }

    /// `.running` holds the clock and `.idle` lets it go.
    func testARunningEngineRunsOnAndAnIdleOneStops() {
        let ran = Ran()
        let renders = Renders()

        renders.render(Ticking(ran: ran, stopAfter: 3).body)
        board.cycle(now: 0, reducesMotion: false)

        for frame in 1...5 {
            board.cycle(now: Double(frame) * 16, reducesMotion: false)
        }

        XCTAssertEqual(ran.order.count, 3, "it ran until it said it was done")
        XCTAssertFalse(board.cycle(now: 96, reducesMotion: false).awake)
    }

    /// An `@EngineState` an engine READ is an `@EngineState` it follows - so a handler
    /// that moves a phase wakes the engine that switches on it, with nothing
    /// saying anywhere that it does.
    func testAPhaseWriteWakesItsReader() {
        let ran = Ran()
        let renders = Renders()
        let view = Switching(ran: ran)

        renders.render(view.body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1)

        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "nothing moved")

        view.step = 4
        board.cycle(now: 48, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 2)
        XCTAssertEqual(view.seen, 4)
    }

    // MARK: - A sequence

    /// A STEP'S CLOCK STARTS WHEN THE STEP IS FIRST LOOKED AT, not when it is
    /// written: a step entered while nothing was cycling would otherwise be
    /// told it had been running for however long the application was asleep.
    func testStepsCountFromTheCycleThatFirstSawIt() {
        var phase = Phase("first")

        XCTAssertNil(phase.entered)
        XCTAssertEqual(phase.elapsed(cycle(at: 1000)), 0)
        XCTAssertEqual(phase.entered, 1000)
        XCTAssertEqual(phase.elapsed(cycle(at: 1120)), 120)

        // AND A STEP RE-ENTERED STARTS OVER, which is what a step that repeats
        // means.
        phase.go(to: "first")

        XCTAssertNil(phase.entered)
        XCTAssertEqual(phase.elapsed(cycle(at: 1200)), 0)
        XCTAssertEqual(phase.elapsed(cycle(at: 1250)), 50)
    }

    /// AND AN ENGINE THAT SWITCHES ON ONE FOLLOWS IT, so a sequence runs to
    /// its end and then stops - the steps being kept in an `@EngineState` like any
    /// other value an engine remembers.
    func testASequenceRunsStepByStepAndThenStops() {
        let ran = Ran()
        let renders = Renders()
        let view = Sequencing(ran: ran)

        renders.render(view.body)

        for frame in stride(from: 0, through: 300, by: 16) {
            board.cycle(now: Double(frame), reducesMotion: false)
        }

        XCTAssertEqual(view.phase.current, .done)

        // It stopped when it reached the last step, and the progress it wrote
        // is the time it spent on the middle one.
        let ranTo = ran.order.count
        board.cycle(now: 400, reducesMotion: false)

        XCTAssertEqual(ran.order.count, ranTo, "a done sequence asks for no more frames")
        XCTAssertEqual(view.progress, 96, accuracy: 20)
    }

    /// Elapsed is PER ENGINE: one that sat out three frames is told about all
    /// three, and one that runs every frame is told about one.
    ///
    /// It has to be, because an engine only runs when something it follows has
    /// moved - so the interval since the LAST CYCLE says nothing about how far
    /// whatever this engine is moving should have got.
    func testElapsedIsCountedPerEngine() {
        let ran = Ran()
        let renders = Renders()
        let view = Doubler(ran: ran)

        renders.render(view.body)

        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        board.cycle(now: 32, reducesMotion: false)
        board.cycle(now: 48, reducesMotion: false)

        view.input = 3
        board.cycle(now: 64, reducesMotion: false)

        XCTAssertEqual(ran.elapsed["doubler"], [16, 48],
                       "the second run is told about every frame since the first")
    }

    /// However long the application was away, no engine is told about more
    /// than a tenth of a second: a gap of minutes handed to arithmetic puts
    /// whatever it moves through the wall.
    func testNoEngineIsToldAboutMoreThanTheMost() {
        let ran = Ran()
        let renders = Renders()

        renders.render(Ticking(ran: ran, stopAfter: 99).body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        // A run of frames the clock kept, each further apart than the last.
        board.cycle(now: 16 + 90, reducesMotion: false)

        XCTAssertEqual(ran.elapsed["ticking"], [16, 90])

        for elapsed in ran.elapsed["ticking"] ?? [] {
            XCTAssertLessThanOrEqual(elapsed, EngineCycle.mostElapsed)
        }
    }

    /// The same cycle over the same image answers the same bytes, whatever
    /// else the process has done - which is what makes any of this testable at
    /// all.
    func testACycleScriptedTwiceWritesTheSameImage() {
        func run() -> [Double] {
            Renderer.shared.clearStates()

            let ran = Ran()
            let renders = Renders()
            let view = Doubler(ran: ran)

            renders.render(view.body)
            board.cycle(now: 0, reducesMotion: false)

            var written: [Double] = []

            for frame in 1...8 {
                view.input = Double(frame) * 1.5
                board.cycle(now: Double(frame) * 16, reducesMotion: false)
                written.append(view.output)
            }

            return written
        }

        XCTAssertEqual(run(), run())
    }

    /// An element that leaves the tree takes its arithmetic with it: nothing
    /// is left being handed frames for a picture nobody can see.
    func testAForgottenEngineIsNotRunAgain() {
        let ran = Ran()
        let renders = Renders()
        let view = Doubler(ran: ran)

        renders.render(VStack { view }.body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1)

        renders.render(VStack { Label("gone") }.body)

        view.input = 9
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 1, "the view has gone, so its engine has")
        XCTAssertEqual(view.output, 0)
    }

    /// AN ENGINE'S OWN READS ARE RECORDED NOWHERE - it runs on the host's
    /// frames, outside any render - so a state only the ARITHMETIC looked at
    /// moves with nothing built again and no engine armed. A view that shows a
    /// value from an engine has to read it in its BODY too, and hand it over.
    ///
    /// Measured live before it was written down: a gallery whose shape and
    /// whose travelling law were read inside its engine alone kept the shape it
    /// was last placed in, however many times the reader asked for another.
    func testAStateOnlyAnEngineReadsArmsNothing() {
        let ran = Ran()
        let renders = Renders()
        let view = Quiet(ran: ran)

        renders.render(view.body)
        _ = board.cycle(now: 0, reducesMotion: false)
        _ = board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 1, "the render armed it once")

        view.$hidden.wrappedValue = 2
        renders.revisit(changed: Renderer.shared.pendingChanges)
        _ = board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 1, """
            a state the body never read is a read nobody recorded, so nothing \
            was built again and the engine was never armed
            """)

        view.$shown.wrappedValue = 1
        renders.revisit(changed: Renderer.shared.pendingChanges)
        _ = board.cycle(now: 48, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 2, """
            and a state the body DOES read rebuilds the view, which is what \
            arms the engine again
            """)
    }
}
