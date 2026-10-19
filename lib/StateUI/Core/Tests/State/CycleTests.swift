// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The cycle: read, work out, write - and every rule that makes running it
// twice over one image answer the same bytes.
//
// Nothing here needs a host. The board is handed an instant and asked for a
// cycle, exactly as `HostBoundary.cycle` hands it one, so every number below
// is exact and none of it depends on a frame ever arriving.

import Synchronization
import XCTest
@_spi(Host) @testable import StateUI

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
private struct Doubler: View {
    @State var input = 0.0
    @State var output = 0.0
    let ran: Ran

    var body: some View {
        Text("doubler").engine(following: $input) { cycle in
            ran.note("doubler", cycle)
            output = input * 2
        }
    }
}

/// A view whose body ends on one kind of control or another, so a change of `round` replaces its element.
private struct Shaped: View {
    let round: Bool

    var body: some View {
        ModifiedContent(node: round ? label("round") : Button("square").node)
    }
}

/// Two engines on one view, written in the order the LOWER priority is second
/// - so a test can see that the order run is the priority's and not the
/// source's.
private struct Ordered: View {
    @State var value = 0.0
    let ran: Ran

    var body: some View {
        Text("ordered")
            .engine(following: $value, priority: 10) { cycle in ran.note("late", cycle) }
            .engine(following: $value, priority: 1) { cycle in ran.note("early", cycle) }
    }
}

/// An engine that READS two `@State`s and names neither in `following:`.
/// Being read wakes nothing: what an engine is woken by is a write to a
/// state it FOLLOWS, and nothing else.
private struct Overhearing: View {
    enum Mode { case a, b }

    @State var level = 0.0
    @State var mode = Mode.a
    @State var out = 0.0
    let ran: Ran

    var body: some View {
        Text("overhearing").engine { cycle in
            ran.note("overhearing", cycle)
            out = mode == .a ? level : -level
            return .wait
        }
    }
}

/// An engine with nothing to follow, which runs on its own answer alone.
private struct Ticking: View {
    @State var count = 0.0
    let ran: Ran
    let stopAfter: Int

    var body: some View {
        Text("ticking").engine { cycle in
            ran.note("ticking", cycle)
            count += 1
            return Int(count) >= stopAfter ? .wait : .again
        }
    }
}

/// An engine following TWO states with a closure of more than one statement -
/// the call shape that told the two `engine` overloads apart the hard way.
private struct Pairing: View {
    @State var left = 0.0
    @State var right = 0.0
    @State var sum = 0.0
    let ran: Ran

    var body: some View {
        Text("pairing").engine(following: $left, $right) { cycle in
            ran.note("pairing", cycle)
            sum = left + right
        }
    }
}

/// A SEQUENCE: an enum naming the step - a value the host cannot carry -
/// followed by the engine that switches on it, and written by that engine to
/// move on.
private struct Stepping: View {
    enum Step { case waiting, counting, done }

    @State var step = Step.waiting
    @State var counted = 0.0
    let ran: Ran

    var body: some View {
        Text("stepping").engine(tracking: $step) { cycle in
            ran.note("stepping \(step)", cycle)

            switch step {
            case .waiting:
                return .wait
            case .counting where counted >= 100:
                step = .done
                return .wait
            case .counting:
                counted += cycle.elapsed
                return .again
            case .done:
                return .wait
            }
        }
    }
}

/// An engine that writes the very state it follows, once per run.
private struct Selfish: View {
    @State var mark = 0
    let ran: Ran

    var body: some View {
        Text("selfish").engine(following: $mark) { cycle in
            ran.note("selfish", cycle)
            mark += 1
        }
    }
}

/// Three engines in a row: one writing `relay` from `trigger`, and two
/// following `relay` - one ahead of the writer in the order, one behind it.
private struct Relaying: View {
    @State var trigger = 0.0
    @State var relay = 0.0
    @State var early = 0.0
    @State var late = 0.0
    let ran: Ran

    var body: some View {
        Text("relaying")
            .engine(following: $relay, priority: -1) { cycle in
                ran.note("before", cycle)
                early = relay
            }
            .engine(following: $trigger, priority: 0) { cycle in
                ran.note("writer", cycle)
                relay = trigger * 10
            }
            .engine(following: $relay, priority: 1) { cycle in
                ran.note("after", cycle)
                late = relay
            }
    }
}

/// ONE STATE IN EVERY ROLE AT ONCE: `shown` is read by the body AND followed
/// by the engine, `quiet` is followed and read by nobody, and `worn` is what
/// the engine writes.
private struct Serving: View {
    @State var shown = 0
    @State var quiet = 0
    @State var worn = 0.0
    let ran: Ran

    var body: some View {
        Text("\(shown)").engine(following: $shown, $quiet) { cycle in
            ran.note("serving", cycle)
            worn = Double(shown + quiet)
        }
    }
}

/// A view with two states: one its BODY shows, one only its ENGINE reads - and
/// a followed state that never moves, so the only thing that can make the
/// engine run again is a render arming it.
private struct Quiet: View {
    @State var shown = 0
    @State var hidden = 1.0
    @State var idle = 0.0
    @State var output = 0.0
    let ran: Ran

    var body: some View {
        Text("\(shown)").engine(following: $idle) { cycle in
            ran.note("quiet", cycle)
            output = hidden
        }
    }
}

/// An engine whose `following:` is an EXPRESSION - one state or another, by
/// a third the body reads - so a render may name a different state than the
/// render before it did.
private struct Choosing: View {
    @State var byFirst = true
    @State var first = 0.0
    @State var second = 0.0
    let ran: Ran

    var body: some View {
        Text("choosing").engine(following: byFirst ? $first : $second) { cycle in
            ran.note("choosing", cycle)
        }
    }
}

/// A parent LENDING a state to a child, as `$step` - the child's engine
/// follows it through the binding, and the owner's write wakes it.
private struct Lending: View {
    @State var step = 0
    let ran: Ran

    var body: some View {
        Borrowing(step: $step, ran: ran)
    }
}

/// The child: a binding to the parent's state, and an engine following it.
private struct Borrowing: View {
    @Binding var step: Int
    let ran: Ran

    var body: some View {
        Text("borrowing").engine(following: $step) { cycle in
            ran.note("borrowing \(step)", cycle)
        }
    }
}

/// A followed state with nothing behind it but its count, written by the test.
private final class Stamped: FollowedState {
    private let written = Atomic(0)

    var stamp: Int { written.load(ordering: .relaxed) }

    /// None: nothing behind it is the host's.
    var reports: Int { 0 }

    func write() { written.add(1, ordering: .relaxed) }
}

@MainActor
final class CycleTests: XCTestCase {
    private var board: CycleBoard { Renderer.shared.board(for: .display) }

    /// A cycle at an instant, for arithmetic that needs one and nothing else.
    private func cycle(at now: Double) -> EngineCycle {
        EngineCycle(sync: .display, now: now, elapsed: 16, count: 1, reducesMotion: false)
    }

    override func setUp() async throws {
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
        trip(Insets(left: 1, top: 2, right: 3, bottom: 4))
        trip(Color("#8040C0FF"))
        trip("a caption, ż and 漢")
        trip("")
        trip(CalendarDate(year: 2026, month: 8, day: 2))
        trip(ClockTime(hour: 9, minute: 30, second: 5))
    }

    /// A TEXT TOLD WHOLE REPLACES THE IMAGE: what the user typed is as long
    /// as its letters, so a report of it cannot be laid lane by lane into the
    /// bytes the last text left - longer words would be cut to the old length
    /// and shorter ones would keep the old tail.
    func testATextToldWholeReplacesTheImage() {
        let words = State(wrappedValue: "x")

        Renders().render(TextField(words.projectedValue).node)

        typed(words.number, "a much longer line of text")
        XCTAssertEqual(words.wrappedValue, "a much longer line of text")

        typed(words.number, "y")
        XCTAssertEqual(words.wrappedValue, "y")
    }

    /// A FIELD HANDED A STATE IS NO READER OF IT. `TextField($name)` reads nothing
    /// at build, so a report of what was typed renders nobody - unless a body
    /// prints the state, which is then the reader and is built again per
    /// keystroke.
    func testAFieldHandedAStateIsNoReaderOfIt() {
        let quiet = Renders()
        let name = State(wrappedValue: "")

        quiet.render(VStack { TextField(name.projectedValue) }.node)
        Renderer.shared.clearInvalidation()

        typed(name.number, "Ada")

        XCTAssertEqual(name.wrappedValue, "Ada", "the typed words landed on the state")
        XCTAssertFalse(Renderer.shared.needsRender, "and nobody read it, so nobody renders")

        let shown = Renders()
        let said = State(wrappedValue: "")

        shown.render(VStack { TextField(said.projectedValue); Text(said.wrappedValue) }.node)
        Renderer.shared.clearInvalidation()

        typed(said.number, "Ada")

        XCTAssertTrue(Renderer.shared.needsRender, "the label that prints the name is a reader, and is asked")
        Renderer.shared.clearInvalidation()
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
        let journey = JourneyLanes(0.25, motion: .eased(.milliseconds(400), .cubicIn))
        var slot = StateImage.bytes(of: journey.carried)
        let whole = slot.count

        // Three lanes of a reading, laid into an image of eight.
        let reading = StateImage.bytes(of: StateCarried.lanes([0.75, 0.75, 0]))

        _ = HostStorage.lay(reading, into: &slot, only: 0b111)

        XCTAssertEqual(slot.count, whole, "the shape is the declaration's")

        let read = JourneyLanes<Double>(carried: StateImage.carried(of: slot, lanes: JourneyLanes<Double>.lanes))

        XCTAssertEqual(read?.value, 0.75, "the lanes it named are laid")
        XCTAssertEqual(read?.destination, 0.75)
        XCTAssertEqual(
            read?.motion, Motion.eased(.milliseconds(400), .cubicIn),
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

    /// A carried state no element wears has no number, so no host reads its lanes: once its write is latched,
    /// nothing is left waiting and the display's clock is let go.
    func testAWriteToAStateNoElementWearsLeavesNothingWaiting() {
        let value = State(wrappedValue: 0.0)
        _ = value.image

        value.wrappedValue = 7
        _ = HostBoundary.cycle(.display, now: 0, reducesMotion: false)

        XCTAssertFalse(HostBoundary.cyclesPending, "nothing waits for a reader that has no number to read")
        XCTAssertEqual(value.wrappedValue, 7)
    }

    // MARK: - The cycle

    /// A state that goes takes the image the host carried it on, and that image its number out of the renderer's
    /// table: a long list of carried rows coming and going leaves both as it found them.
    func testAStateThatGoesLeavesNoNumberBehind() {
        var number: Int32 = 0

        weak var image: HostStorage?
        do {
            let value = State(wrappedValue: 0.0)
            number = value.number
            image = value.image
            XCTAssertNotNil(Renderer.shared.states[number])
        }

        XCTAssertNil(image, "the image the host carried it on goes with it")
        XCTAssertNil(Renderer.shared.states[number], "nothing rides that number any more")
    }

    /// An element replaced - its body now ends on another kind of control - keeps the engines written on it:
    /// they are armed for the new element, not left disarmed with the old one.
    func testAReplacedElementKeepsItsEngines() {
        let ran = Ran()
        let input = State(wrappedValue: 0.0)
        let renders = Renders()

        func tree(_ round: Bool) -> Node {
            stack([
                Shaped(round: round).engine(following: input.projectedValue) { cycle in ran.note("shaped", cycle) }.node,
            ], id: "root")
        }

        renders.render(tree(true))
        board.cycle(now: 0, reducesMotion: false)

        renders.render(tree(false))
        let before = ran.order.count

        input.wrappedValue = 1
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertGreaterThan(ran.order.count, before, "the engine runs on the element that replaced the old one")
    }

    /// The first cycle of all runs what is armed, TOLD NOUGHT. There is no
    /// elapsed time anybody could act on before it, and an engine handed one
    /// would be handed the age of the process; a render that armed it still
    /// wants its answer before anything is drawn.
    func testTheFirstCycleRunsWhatIsArmedToldNought() throws {
        let ran = Ran()
        let renders = Renders()

        renders.render(Doubler(ran: ran).node)

        board.cycle(now: 0, reducesMotion: false)
        XCTAssertEqual(ran.order, ["doubler"], "what is armed runs on the cycle that starts the clock")
        XCTAssertEqual(ran.elapsed["doubler"], [0], "told nought")

        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order, ["doubler"], "and waits on the next")
    }

    /// A STATE WAKES NO ENGINE BY BEING READ, whatever it holds: a state is
    /// followed by NAMING it in `following:`, and one merely looked up inside
    /// the run is nobody's reason to run. Pinned so a sweep cannot fold a
    /// wake-by-read back in.
    func testAStateAnEngineOnlyReadsWakesItNot() {
        let ran = Ran()
        let renders = Renders()
        let view = Overhearing(ran: ran)

        renders.render(view.node)
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
    /// has a pile of writes and a gap no arithmetic should be handed - each
    /// engine with a reason runs over what the cycle latched, told nought.
    func testACycleAfterASilenceRunsToldNought() {
        let ran = Ran()
        let renders = Renders()
        let view = Doubler(ran: ran)

        renders.render(view.node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1)

        // Written while the application was away, which is a reason to run.
        view.input = 5
        board.cycle(now: 5_000, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 2, "the cycle after the gap runs over what it latched")
        XCTAssertEqual(view.output, 10)
        XCTAssertEqual(ran.elapsed["doubler"]?.last, 0, "told nought, not the gap")

        board.cycle(now: 5_016, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 2, "with nothing more to do")
    }

    /// Engines run in ascending PRIORITY, whatever order they were written in
    /// - which is what lets one read what another wrote in the same cycle.
    func testEnginesRunInPriorityOrder() {
        let ran = Ran()
        let renders = Renders()

        renders.render(Ordered(ran: ran).node)
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

        renders.render(view.node)
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

    /// `.again` holds the clock and `.wait` lets it go.
    func testAgainRunsNextCycleAndWaitLetsTheClockGo() {
        let ran = Ran()
        let renders = Renders()

        renders.render(Ticking(ran: ran, stopAfter: 3).node)
        board.cycle(now: 0, reducesMotion: false)

        for frame in 1...5 {
            board.cycle(now: Double(frame) * 16, reducesMotion: false)
        }

        XCTAssertEqual(ran.order.count, 3, "it ran until it said it was done")
        XCTAssertFalse(board.cycle(now: 96, reducesMotion: false).awake)
    }

    /// The plain form takes states of different values and a closure of many
    /// statements: its label alone tells it from the tracking form, so both
    /// take packs. Pinned so the shape stays.
    func testAnEngineFollowsTwoStatesWithAClosureOfManyStatements() {
        let ran = Ran()
        let renders = Renders()
        let view = Pairing(ran: ran)

        renders.render(view.node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "the render armed it once")

        view.left = 2
        view.right = 3
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 2, "both states moved, one run")
        XCTAssertEqual(view.sum, 5)
    }

    // MARK: - One state, every role

    /// A STATE OF ANY TYPE IS FOLLOWED BY NAMING IT: an enum the host cannot
    /// carry, written by a handler, wakes the engine that switches on it.
    func testAFollowedStateOfAnyTypeWakesItsEngine() {
        let ran = Ran()
        let renders = Renders()
        let view = Stepping(ran: ran)

        renders.render(view.node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order, ["stepping waiting"], "the render armed it once")

        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "nothing written, nothing run")

        view.step = .counting
        board.cycle(now: 48, reducesMotion: false)

        XCTAssertEqual(ran.order, ["stepping waiting", "stepping counting"], "a handler's write woke it")
    }

    /// AN ENGINE'S OWN WRITE TO A STATE IT FOLLOWS IS NO REASON TO RUN AGAIN:
    /// where everything it follows stands is written down AFTER the run, so
    /// what it moved itself is what it has already seen. Without this, every
    /// engine that keeps a count in a state it follows would run for ever.
    func testAnEnginesOwnWriteToAFollowedStateWakesItNot() {
        let ran = Ran()
        let renders = Renders()
        let view = Selfish(ran: ran)

        renders.render(view.node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(view.mark, 1, "the render armed it once, and it wrote once")

        board.cycle(now: 32, reducesMotion: false)
        board.cycle(now: 48, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "its own write woke it not")

        view.mark = 10
        board.cycle(now: 64, reducesMotion: false)
        XCTAssertEqual(view.mark, 11, "a handler's write did")

        XCTAssertFalse(board.cycle(now: 80, reducesMotion: false).awake, "and the write it made in answer did not")
        XCTAssertEqual(ran.order.count, 2)
    }

    /// A sequence therefore runs itself to its end and stops: `.again` holds
    /// the clock while it counts, its own move to the last step wakes nothing,
    /// and `.wait` lets the clock go.
    func testASequenceRunsItselfToItsEndAndStops() {
        let ran = Ran()
        let renders = Renders()
        let view = Stepping(ran: ran)

        renders.render(view.node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        view.step = .counting

        for frame in stride(from: 32, through: 300, by: 16) {
            board.cycle(now: Double(frame), reducesMotion: false)
        }

        XCTAssertEqual(view.step, .done)
        XCTAssertGreaterThanOrEqual(view.counted, 100)
        XCTAssertLessThan(view.counted, 120, "it stopped counting the cycle it got there")

        let ranTo = ran.order.count
        XCTAssertFalse(board.cycle(now: 400, reducesMotion: false).awake, "a done sequence asks for no more frames")
        XCTAssertEqual(ran.order.count, ranTo)
    }

    /// A WRITE MADE BY ANOTHER ENGINE IS A SIGNAL LIKE ANY OTHER. A follower
    /// later in the order hears it in the same cycle; one earlier hears it on
    /// the next - and once nobody writes, nobody runs.
    func testAWriteFromAnotherEngineWakesAFollower() {
        let ran = Ran()
        let renders = Renders()
        let view = Relaying(ran: ran)

        renders.render(view.node)
        board.cycle(now: 0, reducesMotion: false)
        XCTAssertEqual(ran.order, ["before", "writer", "after"], "the render armed all three, in priority order")

        view.trigger = 3
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(view.late, 30, "the follower behind the writer heard it in the same cycle")
        XCTAssertEqual(view.early, 0, "the one ahead of it had already run")

        board.cycle(now: 48, reducesMotion: false)
        XCTAssertEqual(view.early, 30, "and hears it on the next")
        XCTAssertEqual(
            ran.order, ["before", "writer", "after", "before", "writer", "after", "before"],
            "the writer and the follower behind it, having seen the write, sat that cycle out")

        XCTAssertFalse(board.cycle(now: 64, reducesMotion: false).awake, "nobody wrote, nobody runs")
    }

    /// EVERY ENGINE IN ONE CYCLE SEES ONE PICTURE. A post made while the engines
    /// run - here by the first - waits for its job, after the cycle: the second
    /// engine sees what the cycle latched, and the next cycle sees the post.
    func testAPostDuringACycleWaitsForTheNextOne() async {
        let value = State(wrappedValue: 1.0)
        let binding = value.projectedValue
        var seen: [Double] = []

        // Carried from here on, on the display's board.
        _ = value.image

        board.arm(EngineEntry(id: 1, priority: 0, sync: .display, follows: []) { _ in
            seen.append(value.wrappedValue)
            binding.post(2)
            return .wait
        })
        board.arm(EngineEntry(id: 2, priority: 1, sync: .display, follows: []) { _ in
            seen.append(value.wrappedValue)
            return .again
        })

        board.cycle(now: 0, reducesMotion: false)
        XCTAssertEqual(seen, [1, 1], "both engines saw the picture the cycle latched")

        await settle()
        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(seen, [1, 1, 2], "the next cycle latched the post")
    }

    /// AN ENGINE FOLLOWS WHAT THE LATEST RENDER NAMED. `following:` is an
    /// expression the body evaluates, so a render may hand the engine other
    /// states than the one before did - and the entry takes them, forgetting
    /// its stamps, rather than going on being woken by the first render's
    /// list for the life of the view.
    func testAnEngineFollowsWhatTheLatestRenderNamed() {
        let ran = Ran()
        let renders = Renders()
        let view = Choosing(ran: ran)

        renders.render(view.node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "the render armed it once")

        view.second = 5
        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "`second` is not followed yet")

        view.first = 5
        board.cycle(now: 48, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 2, "`first` is")

        view.byFirst = false
        renders.render(view.node, changed: Renderer.shared.pendingChanges)
        board.cycle(now: 64, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 3, "the render armed it again")

        view.first = 9
        board.cycle(now: 80, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 3, "`first` is no longer followed")

        view.second = 9
        board.cycle(now: 96, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 4, "`second` is, from the render that named it")
    }

    /// THE HOST'S WRITE IS A SIGNAL TOO, on a state the host carries as the
    /// value itself - what `.frame($room)` makes of a rectangle. Carrying the
    /// state wakes nothing (the image starts at nought and the storage's own
    /// count stops); a report told to the image does.
    func testAHostWriteWakesAnEngineFollowingAPlainState() {
        let ran = Ran()
        let renders = Renders()
        let room = State(wrappedValue: Rect(0, 0, 0, 0))

        renders.render(Text("room").frame(room.projectedValue).engine(following: room.projectedValue) { cycle in
            ran.note("room", cycle)
        }.node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "the render armed it once")

        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "carrying the state is no write")

        moved(room.number, to: [0, 0, 3, 3])
        board.cycle(now: 48, reducesMotion: false)

        XCTAssertEqual(ran.order.count, 2, "the host's report woke it")
        XCTAssertEqual(room.wrappedValue, Rect(0, 0, 3, 3))
    }

    /// A CONVERSION'S SOURCE WRITTEN BY THE HOST re-runs the forward engine:
    /// the differ's engine follows the source's storage, whose stamp counts
    /// the image's writes once the host carries it.
    func testAConversionFollowsASourceTheHostWrites() {
        let renders = Renders()
        let source = State(wrappedValue: 1.0)
        let words = source.projectedValue.convert { "\(Int($0))" }

        renders.render(stack([Slider(source.projectedValue).node, Text().text(words).node]))
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(words.wrappedValue, "1")

        dragged(source.number, to: 5)
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(words.wrappedValue, "5", "the forward engine followed the source's image")
    }

    /// A state LENT to a child is followed through the binding: the child
    /// names `$step` in `following:` exactly as the owner would, and the
    /// owner's write wakes the child's engine.
    func testAStateLentToAChildWakesTheChildsEngine() {
        let ran = Ran()
        let renders = Renders()
        let view = Lending(ran: ran)

        renders.render(view.node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order, ["borrowing 0"])

        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "nothing moved")

        view.step = 4
        board.cycle(now: 48, reducesMotion: false)

        XCTAssertEqual(ran.order, ["borrowing 0", "borrowing 4"], "the owner's write woke the child's engine")
    }

    /// ONE STATE SERVES EVERY ROLE, AND WHERE IT IS USED DECIDES WHICH. Read
    /// by the body and followed by the engine, a write renders the reader AND
    /// wakes the engine; followed and read by nobody, the same write wakes
    /// the engine and renders nothing.
    func testOneStateServesTheBodyAndTheEngine() {
        let ran = Ran()
        let renders = Renders()
        let view = Serving(ran: ran)

        renders.render(view.node)
        Renderer.shared.clearInvalidation()
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1, "the render armed it once")

        view.shown = 2
        XCTAssertTrue(Renderer.shared.needsRender, "the body reads it, so the write asks for a render")

        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 2, "and wakes the engine")
        XCTAssertEqual(view.worn, 2)

        Renderer.shared.clearInvalidation()
        view.quiet = 3
        XCTAssertFalse(Renderer.shared.needsRender, "nobody reads it, so the write asks for nothing")

        board.cycle(now: 48, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 3, "and still wakes the engine")
        XCTAssertEqual(view.worn, 5)
    }

    /// Elapsed is PER ENGINE: one that sat out three frames is told about the
    /// four since it ran, and one that runs every frame is told about one.
    ///
    /// It has to be, because an engine only runs when something it follows has
    /// moved - so the interval since the LAST CYCLE says nothing about how far
    /// whatever this engine is moving should have got.
    func testElapsedIsCountedPerEngine() {
        let ran = Ran()
        let renders = Renders()
        let view = Doubler(ran: ran)

        renders.render(view.node)

        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        board.cycle(now: 32, reducesMotion: false)
        board.cycle(now: 48, reducesMotion: false)

        view.input = 3
        board.cycle(now: 64, reducesMotion: false)

        XCTAssertEqual(ran.elapsed["doubler"], [0, 64],
                       "the second run is told about every frame since the first")
    }

    /// However long the application was away, no engine is told about more
    /// than a tenth of a second: a gap of minutes handed to arithmetic puts
    /// whatever it moves through the wall.
    func testNoEngineIsToldAboutMoreThanTheMost() {
        let ran = Ran()
        let renders = Renders()

        renders.render(Ticking(ran: ran, stopAfter: 99).node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        // A run of frames the clock kept, each further apart than the last.
        board.cycle(now: 16 + 90, reducesMotion: false)

        XCTAssertEqual(ran.elapsed["ticking"], [0, 16, 90])

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

            renders.render(view.node)
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

        renders.render(VStack { view }.node)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(ran.order.count, 1)

        renders.render(VStack { Text("gone") }.node)

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
    /// was last placed in, however many times the user asked for another.
    func testAStateOnlyAnEngineReadsArmsNothing() {
        let ran = Ran()
        let renders = Renders()
        let view = Quiet(ran: ran)

        renders.render(view.node)
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
