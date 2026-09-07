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
    @State var input = 0.0
    @State var output = 0.0
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
    @State var value = 0.0
    let ran: Ran

    var content: Element {
        Label("ordered")
            .engine(following: $value, priority: 10) { cycle in ran.note("late", cycle) }
            .engine(following: $value, priority: 1) { cycle in ran.note("early", cycle) }
    }
}

/// An engine that reads ONE of two `@Memory`s, by a third - the
/// `decision ? first : second` shape inside a run. What it follows must be
/// what it read on its LAST run, and nothing it read earlier.
private struct Choosing: ContentView {
    @Memory var byFirst = true
    @Memory var first = 0.0
    @Memory var second = 0.0
    @State var out = 0.0
    let ran: Ran

    var content: Element {
        Label("choosing").engine { cycle in
            ran.note("choosing", cycle)
            out = byFirst ? first : second
            return .idle
        }
    }
}

/// An engine that READS two `@State`s and names neither in `following:`.
/// Being read wakes nothing: what an engine is woken by is a state it
/// FOLLOWS, or a `@Memory` it read.
private struct Overhearing: ContentView {
    enum Mode { case a, b }

    @State var level = 0.0
    @State var mode = Mode.a
    @State var out = 0.0
    let ran: Ran

    var content: Element {
        Label("overhearing").engine { cycle in
            ran.note("overhearing", cycle)
            out = mode == .a ? level : -level
            return .idle
        }
    }
}

/// An engine with nothing to follow, which runs on its own answer alone.
private struct Ticking: ContentView {
    @State var count = 0.0
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

/// An engine following TWO buses with a closure of more than one statement -
/// the call shape that told the two `engine` overloads apart the hard way.
private struct Pairing: ContentView {
    @State var left = 0.0
    @State var right = 0.0
    @State var sum = 0.0
    let ran: Ran

    var content: Element {
        Label("pairing").engine(following: $left, $right) { cycle in
            ran.note("pairing", cycle)
            sum = left + right
        }
    }
}

/// An engine that switches on a `@Memory` - which it therefore follows,
/// though nothing says so anywhere.
private struct Switching: ContentView {
    @Memory var step = 0
    @State var seen = 0.0
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

    @Memory var phase = Phase(Step.waiting)
    @State var progress = 0.0
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
    @State var idle = 0.0
    @State var output = 0.0
    let ran: Ran

    var content: Element {
        Label("\(shown)").engine(following: $idle) { cycle in
            ran.note("quiet", cycle)
            output = hidden
        }
    }
}

/// A parent LENDING its memory to a child, as `$step` - the child's engine
/// reads it through the link and so follows it.
private struct Lending: ContentView {
    @Memory var step = 0
    let ran: Ran

    var content: Element {
        Linked(step: $step, ran: ran).body
    }
}

/// The child: a link to the parent's memory, and an engine that reads it.
private struct Linked: ContentView {
    @Link var step: Int
    let ran: Ran

    var content: Element {
        Label("linked").engine { cycle in
            ran.note("linked \(step)", cycle)
            return .idle
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

    /// A REPORT SPEAKS ABOUT LANES AND NEVER ABOUT SHAPE: one shorter than the
    /// image lays the lanes it names and leaves the rest of it standing.
    ///
    /// The host reports a two-way control's reading in three lanes, and the
    /// image of a value it walks holds eight - where it is, where it is going,
    /// how fast, the law's three, the waiter and the stop counter. Read as a
    /// value of its own shape the short one REPLACED the image, and the law
    /// went with it: every write after that crossed as a whole new value,
    /// which the host reads as a snap, so a slider that had been touched once
    /// jumped to every value it was sent for the rest of the session.
    func testAShortReportLaysItsLanesAndLeavesTheRestStanding() {
        let journey = AnimatedValue(0.25, motion: .eased(400, .cubicIn))
        var slot = StateImage.bytes(of: journey.carried)
        let whole = slot.count

        // Three lanes of a reading, laid into an image of eight.
        let reading = StateImage.bytes(of: StateCarried.lanes([0.75, 0.75, 0]))

        _ = HostStorage.lay(reading, into: &slot, only: 0b111)

        XCTAssertEqual(slot.count, whole, "the shape is the declaration's")

        let read = AnimatedValue<Double>(carried: StateImage.carried(of: slot, lanes: AnimatedValue<Double>.lanes))

        XCTAssertEqual(read?.value, 0.75, "the lanes it named are laid")
        XCTAssertEqual(read?.setPoint, 0.75)
        XCTAssertEqual(
            read?.motion, Motion.eased(400, .cubicIn),
            "and the law it says nothing about stands")
    }

    /// A write made while no cycle is running is read back at once by whoever
    /// made it - the image is what the program sees - and reaches the CYCLE at
    /// its next latch.
    func testAWriteOutsideACycleIsReadBackAndLatched() {
        let value = State(wrappedValue: 0.0)

        // Carried from here on: a state the host has not been asked to carry
        // is an ordinary one, and a write to it reaches no cycle at all.
        _ = value.image

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

    /// An engine follows what it read on its LAST run - an arm not taken this
    /// time leaves nothing behind to wake it. Reading `first` on one run and
    /// `second` on the next, a write to `first` no longer stirs it, and a write
    /// to `second` does; back on `first`, the other way round.
    func testAnEngineFollowsOnlyWhatItReadOnItsLastRun() {
        let ran = Ran()
        let renders = Renders()
        let view = Choosing(ran: ran)

        renders.render(view.body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "the first run read `byFirst` and `first`")

        view.second = 5
        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "`second` was not read, so writing it wakes nothing")

        view.first = 5
        board.cycle(now: 48, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 2, "`first` was read, so writing it does")

        view.byFirst = false
        board.cycle(now: 64, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 3, "and so was `byFirst` - this run read `second` instead")

        view.first = 7
        board.cycle(now: 80, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 3, "`first` was read on an EARLIER run only, so it wakes nothing now")

        view.second = 7
        board.cycle(now: 96, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 4, "`second` was read on the last run, so it does")
    }

    /// NEITHER A `@State` NOR A `@State` WAKES AN ENGINE BY BEING READ: a bus is
    /// followed by NAMING it in `following:`, and a quiet box is nobody's
    /// reason to run. What an engine must be woken by is a `@Memory`
    /// - the user's decision (2026-09-05), because one wrapper that meant three
    /// things by type and context asked too much of the reader. Pinned so a
    /// sweep cannot fold the wake back in.
    func testAStateAnEngineOnlyReadsWakesItNot() {
        let ran = Ran()
        let renders = Renders()
        let view = Overhearing(ran: ran)

        renders.render(view.body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "the render armed it once")

        view.level = 5
        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "a state it read but never named wakes it not")

        view.mode = .b
        board.cycle(now: 48, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "whatever the state holds")
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

    /// The plain form takes any number of buses of different values and a closure
    /// of any length, and Swift resolves that only with the two forms shaped as
    /// they are - `any Followable` here, a parameter pack on the answering one
    /// (see `Followable`). Pinned so the shape stays.
    func testAnEngineFollowsTwoBusesWithAClosureOfManyStatements() {
        let ran = Ran()
        let renders = Renders()
        let view = Pairing(ran: ran)

        renders.render(view.body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "the render armed it once")

        view.left = 2
        view.right = 3
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 2, "both buses moved, one run")
        XCTAssertEqual(view.sum, 5)
    }

    /// A `@Memory` an engine READ is a `@Memory` it follows - so a handler
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

    /// A LINK to a memory is the memory: an engine in the child that reads it
    /// follows it, and the owner's write wakes that engine.
    func testALinkToAMemoryIsFollowedByReadingIt() {
        let ran = Ran()
        let renders = Renders()
        let view = Lending(ran: ran)

        renders.render(view.body)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order, ["linked 0"])

        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "nothing moved")

        view.step = 4
        board.cycle(now: 48, reducesMotion: false)

        XCTAssertEqual(ran.order, ["linked 0", "linked 4"], "the owner's write woke the child's engine")
    }

    /// And the state walk stops at a link, as at a binding: what it links to
    /// is kept by its owner, and a child holding one owns no box for it.
    func testALinkIsBorrowedAndTheStateWalkStopsAtIt() {
        let memory = Memory(wrappedValue: 0)

        XCTAssertTrue(memory.projectedValue is BorrowedState, "a link is marked, as a binding is")
        XCTAssertEqual(
            stateParts(in: Linked(step: memory.projectedValue, ran: Ran())).boxes.count, 0,
            "a link is no box of the child's")
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
    /// its end and then stops - the steps being kept in a `@Memory` like any
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
