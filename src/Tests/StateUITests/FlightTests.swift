// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Animation as state: a property armed with a binding, and the flight that
// moves it.
//
// What these pin is the whole Swift half of a flight - that the state is given
// its target at once, that the walk rides beside the property it is about
// rather than inside it, that a flight nobody could carry is answered rather
// than left waiting, and that a rebuild in the middle of one says nothing at
// all. The host's half is FlightTests.cs.
//
// EVERY TEST ANSWERS THE FLIGHT BEFORE IT ASSERTS ANYTHING. A flight is
// awaited with `async let`, and a child task that is never resumed is awaited
// again when the test's scope ends - so an assertion that throws between the
// two would turn a red test into a hung one, and the suite would sit there for
// its whole timeout saying nothing.

import StateUIWireProbe
import XCTest
@testable import StateUI

/// A composed view that arms one property with state the test also holds.
///
/// The box itself rather than a `@State` declaration: a property wrapper's
/// memberwise initializer takes the VALUE, so there is no way to hand a view
/// the same storage from outside - which an application never needs and a test
/// always does.
private struct Panel: ContentView {
    let fade: State<Double>

    var content: Element {
        Border {
            Label("Panel")
        }
        .opacity(fade.projectedValue)
    }
}

/// A composed view with nothing of its own, so a modifier written ON it lands
/// on a placeholder - the case the arm's merge exists for.
private struct Plain: ContentView {
    var content: Element {
        Label("Plain")
    }
}

final class FlightTests: XCTestCase {
    /// Answers every act and runs every job, so a suspended handler does not
    /// outlive its test - the shape ConcurrencyTests uses.
    private func quieten() async {
        for _ in 0..<8 {
            for id in WireProbe.completions(Renderer.shared.takeCommandsWire()) {
                ReplyBuffer.current = .finished([.bool(true)])
                _ = Renderer.shared.dispatch(id)
            }

            stateUIRunJobs()
            try? await Task.sleep(nanoseconds: 100_000)
        }
    }

    /// Long enough for a child task to have started its flight and written the
    /// target. Nothing here is timing-based beyond that: what is measured
    /// afterwards is a message, not a moment.
    /// Lets a flight started with `async let` reach `@MainThread`: the child
    /// runs on the cooperative pool and HOPS to book its flight, and the job
    /// that hop lands is run by the host's drain - which this stands in for.
    /// Several rounds, because the job a resume produces lands a moment after
    /// the resume - a superseded flight's answer is one of those.
    private func letTheFlightStart() async {
        for _ in 0 ..< 4 {
            try? await Task.sleep(nanoseconds: 5_000_000)
            stateUIRunJobs()
        }
    }

    /// Says the flight landed, on the channel its transition named, and runs
    /// the job the answer produces - which does not exist yet when `dispatch`
    /// returns, so this asks again until it does, as the host does.
    private func land(_ transition: Transition?) async {
        guard let transition else { return }

        ReplyBuffer.current = .finished([.bool(true)])
        _ = Renderer.shared.dispatch(Int(transition.channel))
        await runTheResume()
    }

    /// Runs the job a resume produces - a landed, settled or superseded
    /// flight's answer - which does not exist yet when the answer is given,
    /// so this asks again until it does, as the host does.
    private func runTheResume() async {
        for _ in 0 ..< 200 {
            if stateUIRunJobs() > 0 { return }
            try? await Task.sleep(nanoseconds: 200_000)
        }
    }

    /// The state gets the target IMMEDIATELY - the semantics the whole design
    /// rests on - and the property crosses as itself, with the walk beside it.
    func testAFlightCommitsTheTargetAndSendsTheWalkBesideIt() async throws {
        let renders = Renders()
        let fade = State(1.0)
        let panel = Panel(fade: fade)

        renders.render(panel.body)

        async let flown: Bool = fade.projectedValue.animateTo(
            0.25, .eased(400, .cubicOut))
        await letTheFlightStart()

        let committed = fade.get()
        let patch = renders.render(panel.body, changed: [ObjectIdentifier(fade.lender)])
        let transition = patch.transitions[.opacity]

        await land(transition)
        let answer = try await flown

        XCTAssertEqual(committed, 0.25, "the state holds the target at once")
        XCTAssertEqual(patch.props[.opacity], .number(0.25), "the target rides as itself")
        XCTAssertEqual(transition?.motion.millis, 400)
        XCTAssertEqual(transition?.motion.curve, .cubicOut)
        XCTAssertEqual(
            transition.map { $0.channel < 0 }, true,
            "a flight answers on one of the completion ids every act answers on")
        XCTAssertTrue(answer, "the host said it ran to the end")

        await quieten()
    }

    /// EVERY FLIGHT RIDES, including one whose target is where the value
    /// already stands.
    ///
    /// A flight is an INSTRUCTION rather than a difference: "walk there", not
    /// "it is different now". A page that starts at 0 and is flown to 0 has a
    /// journey to make, and the host cannot make it unless the message says
    /// so - so a flight cannot be conditioned on the property having changed.
    func testAFlightRidesEvenWhenTheValueDidNotChange() async throws {
        let renders = Renders()
        let fade = State(0.0)
        let panel = Panel(fade: fade)

        // The control already stands at 0 and the host has been told so.
        renders.render(panel.body)

        async let flown: Bool = fade.projectedValue.animateTo(
            1.0, .eased(220, .cubicOut))
        await letTheFlightStart()

        let patch = renders.render(panel.body, changed: [ObjectIdentifier(fade.lender)])

        XCTAssertEqual(
            patch.props[.opacity], .number(1.0),
            "the target rides as itself")
        XCTAssertNotNil(
            patch.transitions[.opacity],
            "the walk rides beside it")

        await land(patch.transitions[.opacity])
        _ = try await flown

        await quieten()
    }

    /// A flight ASKS FOR THE RENDER that carries it - nothing else has to.
    ///
    /// The state it moves is read by the armed modifier itself, so writing the
    /// target invalidates whatever described it, exactly as an assignment
    /// would. A page that flies a value nothing else looks at is the ordinary
    /// case, not a special one.
    func testAFlightAsksForTheRenderThatCarriesIt() async throws {
        let renders = Renders()
        let fade = State(0.0)
        let panel = Panel(fade: fade)

        renders.render(panel.body)

        async let flown: Bool = fade.projectedValue.animateTo(
            1.0, .eased(220, .cubicOut))
        await letTheFlightStart()

        // NOT told what changed: whatever the flight moved is what the walk
        // must have marked, or nothing on screen would ever carry it.
        let patch = renders.render(panel.body)

        XCTAssertEqual(patch.props[.opacity], .number(1.0))
        XCTAssertNotNil(patch.transitions[.opacity])

        await land(patch.transitions[.opacity])
        _ = try await flown

        await quieten()
    }

    /// A rebuild while a flight is in the air says NOTHING about the property:
    /// the state already holds the target, so what the walk re-reads is what
    /// the host was already sent and the diff drops it. This is what makes an
    /// unrelated render free rather than a snap.
    func testARenderInTheMiddleOfAFlightSaysNothingAboutIt() async throws {
        let renders = Renders()
        let fade = State(1.0)
        let panel = Panel(fade: fade)

        renders.render(panel.body)

        async let flown: Bool = fade.projectedValue.animateTo(0.25, .eased(400))
        await letTheFlightStart()

        let carried = renders.render(panel.body, changed: [ObjectIdentifier(fade.lender)])
        let after = renders.render(panel.body)

        await land(carried.transitions[.opacity])
        _ = try await flown

        XCTAssertNotNil(carried.transitions[.opacity], "the flight crossed once")
        XCTAssertNil(after.props[.opacity], "the property the host is walking is not re-sent")
        XCTAssertNil(after.transitions[.opacity], "and neither is the walk")

        await quieten()
    }

    /// A flight to where the value already is has nothing to walk, so nothing
    /// crosses - and it is answered TRUE all the same, because the answer says
    /// the model is where it was going, not that a glide was drawn.
    func testAFlightToWhereTheValueAlreadyIsIsAnsweredWithoutAMessage() async throws {
        let renders = Renders()
        let fade = State(1.0)
        let panel = Panel(fade: fade)

        renders.render(panel.body)

        async let flown: Bool = fade.projectedValue.animateTo(1.0, .eased(400))
        await letTheFlightStart()

        let patch = renders.render(panel.body, changed: [ObjectIdentifier(fade.lender)])
        await runTheResume()
        let answer = try await flown

        XCTAssertNil(patch.transitions[.opacity], "nothing moved, so nothing flies")
        XCTAssertTrue(answer, "the model is where it was going")

        await quieten()
    }

    /// A second flight on the same state takes the first one's place, and the
    /// first is answered FALSE at once rather than left waiting for a walk that
    /// will never be made.
    func testASupersededFlightIsAnsweredFalse() async throws {
        let renders = Renders()
        let fade = State(1.0)
        let panel = Panel(fade: fade)

        renders.render(panel.body)

        async let first: Bool = fade.projectedValue.animateTo(0.25, .eased(400))
        await letTheFlightStart()

        async let second: Bool = fade.projectedValue.animateTo(0.75, .eased(100))
        await letTheFlightStart()

        await runTheResume()
        let firstAnswer = try await first

        let patch = renders.render(panel.body, changed: [ObjectIdentifier(fade.lender)])
        await land(patch.transitions[.opacity])
        _ = try await second

        XCTAssertFalse(firstAnswer, "the flight that was replaced never flew")
        XCTAssertEqual(patch.transitions[.opacity]?.motion.millis, 100, "what crossed is the SECOND")
        XCTAssertEqual(patch.props[.opacity], .number(0.75))

        await quieten()
    }

    /// A binding made from closures borrows from nobody nameable, so there is
    /// nothing to arm and nothing to fly - said out loud, at the call, rather
    /// than silently doing nothing.
    func testABindingWithNoStateBehindItRefusesToFly() async throws {
        nonisolated(unsafe) var held = 1.0
        let binding = Binding(get: { held }, set: { held = $0 })

        do {
            _ = try await binding.animateTo(0.5)
            XCTFail("a binding with no lender cannot fly")
        } catch let error as StateUIError {
            XCTAssertTrue(
                error.message.contains("Binding(get:set:)"),
                "the message names the binding that cannot: \(error.message)")
        }

        XCTAssertEqual(held, 1.0, "and nothing was written")
    }

    /// A DIRTY TREE is work, and the WRITE ITSELF is what wakes the host to
    /// count it.
    ///
    /// A write made inside something the host is driving is rendered by the
    /// drain that follows; a write a `Task.detached` makes from the pool has
    /// nothing following it - no job, no command. Two things keep that write
    /// from waiting for the next touch: the dirty flag counts as work in
    /// `stateui_wait_work`, and `stateChanged` pokes the parked thread AFTER
    /// setting it, so the thread cannot wake, read a clean flag, and park
    /// again with the write behind it. This asks the waker's question with
    /// nothing but the write having happened - `waitForWork` BLOCKS until
    /// something signals, so a write that did not signal would hang here.
    func testAStateWriteAloneWakesTheHostAndReadsAsWork() async throws {
        // Quiet first - and the batch DECODED rather than thrown away, or the
        // names it announced are gone and the next reader dies on them.
        _ = WireProbe.decode(Renderer.shared.takeCommandsWire())
        stateUIRunJobs()
        Renderer.shared.clearInvalidation()

        // Leave the waker with NO signal pending: a poke is coalesced into
        // one the flag already holds, and one wait collects exactly that one
        // and disarms the flag. From here on, only a new signal can wake it.
        MainThreadExecutor.shared.poke()
        _ = MainThreadExecutor.shared.waitForWork()

        let fade = State(1.0)

        await Task.detached { fade.wrappedValue = 0.5 }.value

        XCTAssertTrue(Renderer.shared.needsRender, "a write dirties the tree")
        XCTAssertEqual(Renderer.shared.commandsPending, 0, "and queues no command")
        XCTAssertEqual(MainThreadExecutor.shared.pendingCount, 0, "and lands no job")

        XCTAssertGreaterThan(
            stateui_wait_work(), 0,
            "a dirty tree with no job and no command must read as work, and the "
                + "write alone must have woken the thread that asks")
    }

    /// A flight started from a CHILD TASK is booked and committed on
    /// `@MainThread`, as one step, by the job the child's hop lands.
    ///
    /// The child runs on the cooperative pool. Were it to book and write
    /// there, a render on the UI thread could slip between the two, and two
    /// children on one state could book in one order and write in the other.
    /// So nothing happens on the pool: before the drain the renderer has no
    /// flight and the state holds its old value; the drain runs both.
    func testAFlightFromAChildTaskIsBookedAndCommittedByOneJob() async throws {
        let renders = Renders()
        let fade = State(1.0)
        let panel = Panel(fade: fade)

        renders.render(panel.body)

        async let flown: Bool = fade.projectedValue.animateTo(0.25, .eased(400))
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(
            Renderer.shared.offeredFlights().isEmpty,
            "nothing is booked on the pool")
        XCTAssertEqual(fade.get(), 1.0, "and nothing is written there")
        XCTAssertGreaterThan(
            MainThreadExecutor.shared.pendingCount, 0,
            "the hop is a job, which is also what wakes the host")

        stateUIRunJobs()

        XCTAssertEqual(Renderer.shared.offeredFlights().count, 1, "the drain books it")
        XCTAssertEqual(fade.get(), 0.25, "and commits it, in the same job")

        let patch = renders.render(panel.body, changed: [ObjectIdentifier(fade.lender)])
        await land(patch.transitions[.opacity])
        let answer = try await flown
        XCTAssertTrue(answer)

        await quieten()
    }

    /// Two flights on ONE state from two child tasks: whichever is booked
    /// second is the one the state holds the target of - always, because
    /// booking and committing are one job each, and the jobs run one at a
    /// time on one thread. The flight that answers true is the flight whose
    /// target is on the screen.
    func testTwoChildFlightsOnOneStateLeaveTheLiveOnesTarget() async throws {
        let renders = Renders()
        let fade = State(1.0)
        let panel = Panel(fade: fade)

        renders.render(panel.body)

        async let first: Bool = fade.projectedValue.animateTo(0.25, .eased(400))
        async let second: Bool = fade.projectedValue.animateTo(0.75, .eased(100))
        try? await Task.sleep(nanoseconds: 20_000_000)

        stateUIRunJobs()

        let live = try XCTUnwrap(Renderer.shared.offeredFlights().values.first)
        let patch = renders.render(panel.body, changed: [ObjectIdentifier(fade.lender)])
        await land(patch.transitions[.opacity])

        let firstFlew = try await first
        let secondFlew = try await second
        let landed = firstFlew ? 0.25 : 0.75
        let length: UInt32 = firstFlew ? 400 : 100

        XCTAssertNotEqual(firstFlew, secondFlew, "one flew, one was superseded")
        XCTAssertEqual(fade.get(), landed, "the state holds the target of the flight that flew")
        XCTAssertEqual(patch.props[.opacity], .number(landed), "which is what crossed")
        XCTAssertEqual(
            patch.transitions[.opacity]?.motion.millis, length,
            "beside the walk of that same flight")
        XCTAssertEqual(live.motion.millis, length)

        await quieten()
    }

    // MARK: - A two-way input's own value

    /// The value a two-way input BORROWS is armed with the state behind it, so
    /// the control can be flown to a value the reader could also have dragged
    /// it to.
    ///
    /// `Slider` and `Stepper` are the whole of this: they are the only two
    /// controls taking a binding in their initializer whose type is one the
    /// host walks. The other eight borrow a `String`, a `Bool` or a date.
    func testATwoWayInputsValueIsArmedWithItsBinding() async throws {
        let renders = Renders()
        let volume = State(0.2)

        renders.render(Slider(volume.projectedValue).body)

        async let flown: Bool = volume.projectedValue.animateTo(1, .eased(400, .cubicOut))
        await letTheFlightStart()

        let patch = renders.render(
            Slider(volume.projectedValue).body, changed: [ObjectIdentifier(volume.lender)])
        let transition = patch.transitions[.value]

        await land(transition)
        let answer = try await flown

        XCTAssertEqual(patch.props[.value], .number(1), "the target rides as itself")
        XCTAssertEqual(transition?.motion.millis, 400, "and the walk beside it")
        XCTAssertEqual(transition?.motion.curve, .cubicOut)
        XCTAssertTrue(answer)

        await quieten()
    }

    /// A report arriving WHILE the value flies is ignored.
    ///
    /// The platform raises a two-way input's report for a value it is itself
    /// walking as readily as for a finger - measured on a MAUI `Slider`: five
    /// assignments to `Value`, five `ValueChanged`. Writing one back would be
    /// an assignment to an armed property, and `SwiftFlights.Interrupt` aborts
    /// a walk the moment a message re-describes its property - so the flight
    /// would die on its own first frame, having asked for a render on the way
    /// and every frame after until it did.
    ///
    /// The state stands at the TARGET the whole way, which is the model, so
    /// there is nothing an intermediate report could correctly say.
    func testAReportIsIgnoredWhileTheValueIsFlying() async throws {
        let renders = Renders()
        let volume = State(0.2)

        let first = renders.render(Slider(volume.projectedValue).body)
        let report = try XCTUnwrap(first.events?["valueChanged"])

        // Before any flight, a drag is written - which is what two-way MEANS,
        // and what the guard must not have taken away.
        XCTAssertTrue(renders.fire(report, with: [.number(0.5)]))
        XCTAssertEqual(volume.get(), 0.5, "an ordinary drag still writes")

        async let flown: Bool = volume.projectedValue.animateTo(1, .eased(400))
        await letTheFlightStart()

        let carried = renders.render(
            Slider(volume.projectedValue).body, changed: [ObjectIdentifier(volume.lender)])
        XCTAssertNotNil(carried.transitions[.value], "the flight was handed over")

        // What the platform raises as it walks the control.
        XCTAssertTrue(renders.fire(report, with: [.number(0.7)]))
        XCTAssertEqual(volume.get(), 1, "the state stands at the target the whole way")

        await land(carried.transitions[.value])
        _ = try await flown

        // And once it has landed the control is the reader's again. THIS is
        // the assertion that found the leak: `flown` was written when a render
        // handed a flight over and removed nowhere, so a state that had ever
        // flown read as flying for the rest of the session - and this slider
        // would have ignored every drag it was ever given afterwards.
        XCTAssertTrue(renders.fire(report, with: [.number(0.3)]))
        XCTAssertEqual(volume.get(), 0.3, "a drag after the flight writes again")

        await quieten()
    }

    /// Every armed modifier names a real property of the same name, of a value
    /// type the host can walk.
    ///
    /// A `Binding` overload for a property nothing declares, or for a value
    /// nothing interpolates, would compile and then do nothing at all - which
    /// is the one failure this library refuses to ship.
    func testEveryArmedModifierNamesAWalkablePropertyOfTheSameName() throws {
        let sources = try Fixtures.allSources()
        let armed = try XCTUnwrap(sources.first { $0.path.hasSuffix("Views/Armed.swift") })

        var overloads: [(name: String, type: String)] = []

        for line in armed.text.split(separator: "\n") {
            let written = String(line)

            guard let name = written.occurrences(between: "public func ", and: "(").first,
                  let type = written.occurrences(between: "Binding<", and: ">").first
            else { continue }

            overloads.append((name, type))
        }

        XCTAssertGreaterThan(
            overloads.count, 20, "the scan found too few overloads to be reading the right thing")

        // What the host has a blend for, and the whole of it - a number, a
        // colour and a thickness. See SwiftAnimations.Transform.
        let walkable: Set<String> = ["Double", "Color", "Thickness"]

        // Line by line, deliberately: a scan over a whole file would read from
        // one declaration's "public func " to a LATER one's "(_ value:" and
        // come back with everything in between.
        var values: Set<String> = []

        for source in sources where !source.path.hasSuffix("Views/Armed.swift") {
            for line in source.text.split(separator: "\n") {
                values.formUnion(
                    String(line).occurrences(between: "public func ", and: "(_ value:"))
            }
        }

        for overload in overloads {
            XCTAssertTrue(
                walkable.contains(overload.type),
                "`\(overload.name)` is armed with a \(overload.type), which nothing walks")
            XCTAssertTrue(
                values.contains(overload.name),
                "`\(overload.name)` is armed but no modifier of that name takes a value")
        }
    }

    /// Nothing that could be animated before flights was lost by them.
    ///
    /// The eleven names are the FLOOR of the armed surface, written out here
    /// rather than read from the library, so shrinking what arms fails this
    /// test by name instead of silently.
    func testNothingAnimatableBeforeFlightsWasLost() throws {
        let armed = try XCTUnwrap(
            try Fixtures.allSources().first { $0.path.hasSuffix("Views/Armed.swift") })

        let before = [
            "backgroundColor", "widthRequest", "heightRequest", "margin", "padding",
            "fontSize", "textColor", "characterSpacing", "borderColor", "borderWidth",
        ]

        var armedNames: Set<String> = []

        for line in armed.text.split(separator: "\n") {
            armedNames.formUnion(
                String(line).occurrences(between: "public func ", and: "(_ binding:"))
        }

        for name in before {
            XCTAssertTrue(
                armedNames.contains(name),
                "`\(name)` could be animated before flights and has no armed form now")
        }

        // `cornerRadius` was the eleventh and is deliberately NOT here: MAUI
        // declares Button.CornerRadius an Int, nothing walks a whole number,
        // and the token threw on every platform the moment it was used.
        XCTAssertFalse(
            armedNames.contains("cornerRadius"),
            "Button.CornerRadius is an Int in MAUI and cannot be walked")
    }

    /// The bytes themselves, pinned - because a transition is a new FIELD on
    /// the wire and the field markers are a space that runs out.
    ///
    /// The channel is written by hand as -1 rather than taken from the
    /// renderer's counter, which counts down across a whole session and would
    /// make these bytes depend on how many acts happened to run before them.
    /// The command fixtures normalize the same number for the same reason.
    func testAFlightIsWrittenDown() throws {
        let differ = Differ()
        let fade = State(1.0)
        let panel = Panel(fade: fade)

        let dictionary = WireDictionary()
        let names = WireNames()

        // The opening message: the border at the value the flight starts FROM,
        // which the host's half applies before it applies the flight.
        let first = differ.reconcile(nil, with: panel.body)
        let opening = Wire.encode(first.patch, generation: 1, dictionary: dictionary)
        try Fixtures.check(
            opening,
            sidecar: WireProbe.dumpMessage(opening, names: names),
            against: "flying-first")

        fade.wrappedValue = 0.25
        differ.flights = [
            FlightKey(lender: ObjectIdentifier(fade.lender), lent: nil):
                PendingFlight(
                    motion: .eased(400, .cubicOut), channel: -1,
                    report: 0, lender: fade.lender)
        ]

        let flying = differ.reconcile(
            first.node,
            with: panel.body,
            changed: [ObjectIdentifier(fade.lender)])

        let bytes = Wire.encode(flying.patch, generation: 2, dictionary: dictionary)
        try Fixtures.check(
            bytes, sidecar: WireProbe.dumpMessage(bytes, names: names), against: "flying")

        _ = differ.takeCarried()
    }

    /// The same walk, WATCHED: the only difference on the wire is one more
    /// field on the transition, the cadence the author stated.
    func testAWatchedFlightIsWrittenDown() throws {
        let differ = Differ()
        let fade = State(1.0)
        let panel = Panel(fade: fade)

        let dictionary = WireDictionary()
        let names = WireNames()

        let first = differ.reconcile(nil, with: panel.body)
        let opening = Wire.encode(first.patch, generation: 1, dictionary: dictionary)

        // Dumped and thrown away: the names this session announced are announced
        // ONCE, by the message that first uses them, so the reader of the second
        // message has to have read the first - the same reason the C# half reads
        // `flying-first` before `flying`.
        _ = WireProbe.dumpMessage(opening, names: names)

        fade.wrappedValue = 0.25
        differ.flights = [
            FlightKey(lender: ObjectIdentifier(fade.lender), lent: nil):
                PendingFlight(
                    motion: .eased(400, .cubicOut), channel: -1,
                    report: 100, lender: fade.lender)
        ]

        let flying = differ.reconcile(
            first.node,
            with: panel.body,
            changed: [ObjectIdentifier(fade.lender)])

        let bytes = Wire.encode(flying.patch, generation: 2, dictionary: dictionary)
        try Fixtures.check(
            bytes,
            sidecar: WireProbe.dumpMessage(bytes, names: names),
            against: "flying-watched")

        _ = differ.takeCarried()
    }

    /// A walk the author asked to WATCH: the cadence rides the transition, the
    /// host's samples land in the second piece of state, and the flight's own
    /// answer has the last word about where it ended.
    func testAWatchedFlightWritesEverySampleAndThenTheTarget() async throws {
        let renders = Renders()
        let fade = State(1.0)
        let shown = State(1.0)
        let panel = Panel(fade: fade)

        renders.render(panel.body)

        async let flown: Bool = fade.projectedValue.animateTo(
            0.2, .eased(400, .linear),
            reporting: shown.projectedValue, every: 100)
        await letTheFlightStart()

        let patch = renders.render(panel.body, changed: [ObjectIdentifier(fade.lender)])
        let transition = patch.transitions[.opacity]

        XCTAssertEqual(transition?.report, 100, "the cadence is the author's, and it crosses")
        XCTAssertEqual(fade.get(), 0.2, "the model stands at the target the whole way")

        // What the host says a frame later. The state the author is WATCHING
        // with moves; the state that is flying does not, or the walk would end.
        let channel = transition!.channel
        XCTAssertTrue(Renderer.shared.reported(channel, .number(0.6)))
        XCTAssertEqual(shown.get(), 0.6)
        XCTAssertEqual(fade.get(), 0.2)

        await land(transition)
        let answer = try await flown

        XCTAssertTrue(answer)
        XCTAssertEqual(
            shown.get(), 0.2,
            "a walk that ran to the end is AT the target, and says so exactly")

        XCTAssertFalse(
            Renderer.shared.reported(channel, .number(0.9)),
            "a sample that crosses after the answer finds nobody, and writes nothing")
        XCTAssertEqual(shown.get(), 0.2)

        await quieten()
    }

    /// The arm survives being written ON a composed view, where the modifier
    /// lands on a placeholder and has to be merged into the content when it is
    /// built. Without that merge this compiles, renders and animates nothing.
    func testAPropertyArmedOnAComposedViewStillFlies() async throws {
        let renders = Renders()
        let fade = State(1.0)

        renders.render(Plain().opacity(fade.projectedValue).body)

        async let flown: Bool = fade.projectedValue.animateTo(0.5, .eased(120))
        await letTheFlightStart()

        let patch = renders.render(
            Plain().opacity(fade.projectedValue).body,
            changed: [ObjectIdentifier(fade.lender)])

        await land(patch.transitions[.opacity])
        _ = try await flown

        XCTAssertEqual(
            patch.transitions[.opacity]?.motion.millis, 120,
            "an arm written on a composed view has to reach the content it stands for")

        await quieten()
    }
}
