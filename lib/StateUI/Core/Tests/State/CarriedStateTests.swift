// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The path that describes nothing: a value the platform moves many times a
// second, and the arithmetic that follows it.
//
// What has to hold, and each of these is one test below: a write records
// nothing and asks for no render; the value is still THERE for whoever reads
// it; an element that drives a property says so in its message, by the state's
// number, its mode and its door; and `.inherited` on such a value means THIS
// element's law, resolved on this side because the host cannot read a motion
// plan.
//
// The mechanism is in Core/Carried; a host's half - which runs the cycle on
// the platform's own frames and writes the values onto the controls - is the
// host layer's `StateChannels` and `DisplayCycle`.

import XCTest
@_spi(Host) @testable import StateUI

/// A view on a carried state somebody else declared, reading it - so a test can
/// see that reading one records nothing, and that `@Binding` is how a carried
/// state is handed down.
private struct Follower: View {
    @Binding var value: Double
    let builds: Builds

    var body: some View {
        builds.count += 1
        return AnyView(node: label("at \(value)"))
    }
}

/// A view on a carried state somebody else declared, writing it - which is what
/// `@Binding` is for, and the shape a child takes a carried state in.
private struct Rider: View {
    @Binding var level: Double

    var body: some View { AnyView(node: label("riding")) }

    /// A handler's write, as a child handed the binding makes one.
    func bump() { level += 1 }
}

/// A view handing a state somebody else declared to the host to walk: a
/// driven property and no read, which is the channel a host writes it through.
private struct Driver: View {
    @Binding var level: Double

    var body: some View { Text("driving").rotation($level) }
}

/// A view holding a driven state of its OWN, so a test can watch the wrapper a second
/// render builds take over the storage the first one made.
private struct Holder: View {
    @State var choice = false
    let seen: Seen

    /// Something to build the holder with a second time: a view built with
    /// the same inputs is carried, and these tests need it BUILT.
    var tag = 0

    var body: some View {
        seen.numbers.append($choice.number ?? -1)
        seen.values.append(choice)
        return Switch($choice)
    }
}

/// A view counting with a state of its own, so a test can place ONE value of it twice.
private struct Tally: View {
    @State private var count = 0

    var body: some View { Button("\(count)").onClicked { count += 1 } }
}

/// A view counting with a state of its own, held in a property by the view below.
private struct Counted: View {
    @State private var count = 0

    var body: some View { Button("counted \(count)").onClicked { count += 1 } }
}

/// A view holding another in a property and placing it once: the holder's walk meets the held view's box before
/// the held view's own place does - one lineage, not two places.
private struct Holding: View {
    let counted = Counted()

    var body: some View { VStack { counted } }
}

/// A composed view with nothing of its own written on it, so a test can write
/// a driven state ON it and look for the registration on the element its body ends at.
private struct Plain: View {
    var body: some View { Text("plain") }
}

/// What each render of the holder saw. A class, for the same reason.
private final class Seen {
    var numbers: [Int32] = []
    var values: [Bool] = []
}

/// Counts builds. A class, so the walk that collects state boxes leaves it
/// alone.
private final class Builds {
    var count = 0
}

/// A view that makes its own state in its initializer and keeps the state's binding there too.
private struct EarlyBinding: View {
    @State var owner: Double
    let borrowed: Binding<Double>
    let revision: Int

    init(seed: Double, revision: Int) {
        let state = State(seed)
        _owner = state
        borrowed = state.projectedValue
        self.revision = revision
    }

    var body: some View {
        VStack {
            Slider(borrowed).id("slider")
            Text(String(owner)).id("readout")
        }
    }
}

/// A view that makes its own list in its initializer and keeps a part of it there too.
private struct EarlyPart: View {
    @State var owner: [Int]
    let part: StatePart<Int>
    let revision: Int

    init(seed: [Int], revision: Int) {
        let state = State(seed)
        _owner = state
        part = state.projectedValue[0]
        self.revision = revision
    }

    var body: some View { Text(String(owner[0])) }
}

/// A view that makes its own state in its initializer and keeps a conversion of it - of it alone, or with a second
/// state of its own - there too.
private struct EarlyConversion: View {
    @State var owner: Double
    @State var other: Double
    let derived: Binding<Double>
    let revision: Int

    init(seed: Double, revision: Int, multi: Bool = false) {
        let (state, second) = (State(seed), State(0.0))
        (_owner, _other) = (state, second)
        derived = multi
            ? Binding<Double>.multi(state.projectedValue, second.projectedValue).convert({ ($0 + $1) * 100 }) { ($0 / 100, 0) }
            : state.projectedValue.convert({ $0 * 100 }, back: { $0 / 100 })
        self.revision = revision
    }

    var body: some View { Slider(derived).maximum(100) }
}

/// What a view keeps across its builds: the binding of its state as built last, a conversion made once, and the
/// box the conversion was made from - weakly, to see it leave.
@MainActor
private final class Kept {
    var current: Binding<Double>?
    var derived: Binding<Double>?
    weak var box: AnyObject?
}

/// A view whose body keeps the conversion its first build made, over every rebuild.
private struct KeepsItsConversion: View {
    @State var value = 0.2
    let kept: Kept
    let revision: Int

    var body: some View {
        kept.current = $value
        if kept.derived == nil {
            kept.box = _value
            kept.derived = $value.convert({ $0 * 100 }, back: { $0 / 100 })
        }
        return Slider(kept.derived!).maximum(100)
    }
}

/// A view whose initializer, at `revision` 1, makes a conversion of the fresh state - before that state's box adopts
/// the one kept - and keeps it for every build after.
private struct KeepsAnEarlyConversion: View {
    @State var value: Double
    let kept: Kept
    let revision: Int

    init(seed: Double, revision: Int, kept: Kept) {
        let state = State(seed)
        _value = state
        self.kept = kept
        self.revision = revision
        if revision == 1 {
            kept.box = state
            kept.derived = state.projectedValue.convert({ $0 * 100 }, back: { $0 / 100 })
        }
    }

    var body: some View {
        kept.current = $value
        return Slider(kept.derived ?? $value).maximum(100)
    }
}

/// A view with a state of its own and a slider over a conversion of it.
private struct OwnedSlider: View {
    @State var value = 0.2
    let revision: Int

    var body: some View {
        Slider($value.convert({ $0 * 100 }, back: { $0 / 100 })).maximum(100)
    }
}

/// A view that makes its own list in its initializer and keeps its binding there too.
private struct EarlyList: View {
    @State var value: [Int]
    let early: Binding<[Int]>
    let revision: Int

    init(seed: [Int], revision: Int) {
        let state = State(seed)
        _value = state
        early = state.projectedValue
        self.revision = revision
    }

    var body: some View { Text(String(value[0])) }
}

@MainActor
final class CarriedStateTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    // MARK: - The value

    /// Writing one asks for no render and names no change - which is the whole
    /// of what makes it affordable to move with a finger.
    func testWritingACarriedStateAsksForNoRender() {
        let value = State(wrappedValue: 0.0)

        value.wrappedValue = 40

        XCTAssertEqual(value.wrappedValue, 40)
        XCTAssertFalse(Renderer.shared.needsRender)
        XCTAssertTrue(Renderer.shared.pendingChanges.isEmpty)
    }

    /// A READ AT BUILD RECORDS THE DEPENDENCY, carried or not: a body that
    /// prints the value is rebuilt when it moves, exactly as it is for any
    /// state. What asks for no render is a state nobody reads at build - one
    /// handed on as `$x` alone - which the test after this one holds. There is
    /// no second rule for a carried state, and that is the point.
    func testAReadAtBuildRecordsTheDependency() {
        let value = State(wrappedValue: 0.0)
        let builds = Builds()
        let renders = Renders()

        renders.render(stack([Follower(value: value.projectedValue, builds: builds).node], id: "root"))
        XCTAssertEqual(builds.count, 1)

        value.wrappedValue = 12
        renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(builds.count, 2, "the body read it, so the body is built again")
    }

    /// And a state read at NO build asks for nothing however often it moves:
    /// a view that only holds `$x` - to drive a property, to write from a
    /// handler - is never rebuilt for it.
    func testAStateNobodyReadsAtBuildAsksForNothing() {
        let value = State(wrappedValue: 0.0)
        let renders = Renders()

        renders.render(stack([Rider(level: value.projectedValue).node], id: "root"))
        Renderer.shared.clearInvalidation()

        value.wrappedValue = 12

        XCTAssertFalse(Renderer.shared.needsRender, "nothing read it at build")
        XCTAssertTrue(Renderer.shared.pendingChanges.isEmpty)
    }

    /// A JOURNEY'S OWN MACHINERY MAKES NO READER, wherever it runs.
    ///
    /// `move(to:)` reads the value it is about to move, and a completion
    /// answered while a render is running resumes the handler INSIDE that
    /// build - so a recorded read would land in whatever element's scope is
    /// open and make that element a reader of a state it never mentions.
    /// Measured on the gallery: one card's press animation made the window a
    /// reader of the card's own `dip`, and from then on every example opened
    /// at two builds instead of one, the second being a whole-tree render for
    /// a value nothing showed.
    ///
    /// The read is taken with a scope OPEN, which is what a build looks like.
    func testAJourneysOwnMachineryMakesNoReader() {
        let dip = State(wrappedValue: 1.0)
        let renders = Renders()

        renders.render(stack([ZStack { Text("x") }.scale(dip.projectedValue).node], id: "root"))
        Renderer.shared.clearInvalidation()

        // A build's scope, and the machinery of a write running inside it -
        // which is where a resumed handler runs when a completion is answered
        // mid-render.
        let (_, reads) = ReadScope.collect {
            dip.projectedValue.journey.destination = 0.96
            dip.projectedValue.journey.snap(to: 0.96)
            dip.projectedValue.journey.stop()
        }

        XCTAssertTrue(reads.isEmpty, "a write reading what it changes is not a dependency")
        XCTAssertFalse(dip.storage.readAtBuild, "and it is not a read at build either")
    }

    /// The host says where it stands by the number it was issued, and the
    /// value is then what anything reading it sees - a handler asking where
    /// the run is, and the arithmetic itself.
    func testTheHostMovesItByItsNumber() {
        let value = State(wrappedValue: 0.0)

        Renders().render(Driver(level: value.projectedValue).node)
        dragged(value.number, to: 91.5)

        XCTAssertEqual(value.wrappedValue, 91.5)
    }

    /// A HOST write is a write like any other: the body that read the state at
    /// build is rendered for it, and a body that only holds `$x` is not -
    /// which is the whole cost of showing a moving value, paid only where a
    /// body prints it.
    func testAHostWriteRebuildsTheReadersAndNobodyElse() {
        let value = State(wrappedValue: 0.0)
        let builds = Builds()
        let renders = Renders()

        renders.render(stack([
            Follower(value: value.projectedValue, builds: builds).node,
            Rider(level: value.projectedValue).node,
            Driver(level: value.projectedValue).node,
        ], id: "root"))
        Renderer.shared.clearInvalidation()

        dragged(value.number, to: 12)

        XCTAssertTrue(Renderer.shared.needsRender, "a body printed it, so the host's write renders")
        renders.revisit(changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(builds.count, 2, "the reader is built again, and only the reader")
        XCTAssertEqual(value.wrappedValue, 12)
    }

    /// A HOST WRITE ASKS AT ONCE, like every other write: there is no cadence
    /// on a state at all. What a view asks for is a READING of where a walked
    /// value has got to, into a state of its own - `.samples(_:into:_:)`, in
    /// Sampling.swift - and the source goes on saying its destination.
    func testAHostWriteAsksAtOnce() {
        let value = State(wrappedValue: 0.0)
        let builds = Builds()
        let renders = Renders()

        renders.render(stack([
            Follower(value: value.projectedValue, builds: builds).node,
            Driver(level: value.projectedValue).node,
        ], id: "root"))
        Renderer.shared.clearInvalidation()

        dragged(value.number, to: 1)
        XCTAssertTrue(Renderer.shared.needsRender, "the first write asks at once")
        Renderer.shared.clearInvalidation()

        dragged(value.number, to: 2)
        XCTAssertTrue(Renderer.shared.needsRender, "and so does the next")
        XCTAssertEqual(value.wrappedValue, 2)
    }

    /// A twin over a member that travels is walked as a journey, whatever the member: a grid's spacings and a label's
    /// line height glide from a state as their described values do.
    func testATwinOverATravelingMemberIsAJourney() {
        let rows = State(wrappedValue: 8.0)
        let columns = State(wrappedValue: 4.0)
        let line = State(wrappedValue: 20.0)

        let grid = Renders().render(Grid {}.rowSpacing(rows.projectedValue).columnSpacing(columns.projectedValue).node)
        let text = Renders().render(Text("Words").lineHeight(line.projectedValue).node)

        XCTAssertEqual(grid.driven?["Grid.rowSpacing"]?.kind, .property)
        XCTAssertEqual(grid.driven?[.columnSpacing]?.kind, .property)
        XCTAssertEqual(text.driven?[.lineHeight]?.kind, .property)
    }

    /// `Slider($volume)` over a plain `Double` is HANDED OVER: the host walks
    /// the value as a journey, the slider reads nothing at build, an
    /// assignment moves the destination alone, and a drag is the host's write
    /// onto value and destination together.
    func testASliderOverADoubleIsCarriedAsAJourney() {
        let volume = State(wrappedValue: 0.25)
        let renders = Renders()

        let patch = renders.render(Slider(volume.projectedValue).node)

        XCTAssertNil(patch.props[.value], "nothing is described: the value rides the image")
        XCTAssertEqual(patch.driven?[.value]?.mode, .inOut)
        XCTAssertEqual(patch.driven?[.value]?.kind, .property)

        let board = Renderer.shared.board
        board.cycle(now: 0, reducesMotion: false)
        _ = board.dirty()

        volume.wrappedValue = 0.75
        board.cycle(now: 16, reducesMotion: false)

        let sent = board.dirty().first { $0.number == volume.number }

        XCTAssertEqual(volume.wrappedValue, 0.75, "the state answers where it is going")
        XCTAssertNotEqual(sent.map { $0.mask & JourneyLanes<Double>.mask(of: .destination) }, 0,
                          "the destination crossed")
        XCTAssertEqual(sent.map { $0.mask & JourneyLanes<Double>.mask(of: .value) }, 0,
                       "and the value did not: the host walks it there")

        dragged(volume.number, to: 0.5)

        XCTAssertEqual(volume.wrappedValue, 0.5, "a drag arrives")
    }

    /// And what it costs: a frame of a walk moves the value's lane alone and
    /// renders nobody, a drag moves the destination and renders whoever
    /// printed the state - the slider itself never being a reader of it.
    func testASlidersReportRendersItsReadersAndAWalkRendersNobody() {
        let volume = State(wrappedValue: 0.0)
        let builds = Builds()
        let renders = Renders()

        renders.render(stack([
            Follower(value: volume.projectedValue, builds: builds).node,
            Slider(volume.projectedValue).node,
        ], id: "root"))
        Renderer.shared.clearInvalidation()

        // A frame of a walk: the value's lane alone.
        moved(volume.number, to: [0.3, 1, 0, 0, 0, 0, 0, 0], mask: 0b1)

        XCTAssertFalse(Renderer.shared.needsRender, "where it is going did not change")

        // A drag: value and destination together.
        dragged(volume.number, to: 0.5)

        XCTAssertTrue(Renderer.shared.needsRender, "the destination moved")
        renders.revisit(changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(builds.count, 2, "the body that printed it, and nobody else")

        // The host writing the destination BACK - on landing, or a report
        // that says where it already was - is nothing to show.
        Renderer.shared.clearInvalidation()
        dragged(volume.number, to: 0.5)

        XCTAssertFalse(Renderer.shared.needsRender, "where it is going did not change")
    }

    /// One state has ONE shape. A state a feed carries as the value itself -
    /// its number issued, so the host may be writing one lane into it - cannot
    /// also be walked as a journey, and the second hand-over is refused and
    /// said rather than silently wearing the wrong lanes.
    func testAStateHasOneShapeAndTheSecondHandOverIsRefused() {
        let offset = State(wrappedValue: 0.0)

        _ = offset.number

        XCTAssertNil(offset.projectedValue.journeyImage, "carried as the value, so no journey")
        XCTAssertEqual(offset.projectedValue.journey.value, 0,
                       "and its journey stands at the value, saying nothing")

        let volume = State(wrappedValue: 0.0)

        _ = volume.projectedValue.journeyImage

        XCTAssertNil(volume.projectedValue.image, "carried as a journey, so not as the value")
        XCTAssertNotNil(volume.projectedValue.followed, "and an engine follows it all the same")
    }

    /// A HOST WRITE IS A SIGNAL. `.engine(following: $v)` on a container is
    /// declared BEFORE the container's content hands `$v` to the slider inside
    /// it, and follows the state's storage rather than any image - so when the
    /// drag lands on the journey the slider walks, the image's stamp moves,
    /// the storage's stamp with it, and the engine runs on the next cycle and
    /// reads the landed value.
    func testAHostDragWakesAnEngineFollowingTheState() {
        let volume = State(wrappedValue: 0.2)
        let reading = State(wrappedValue: "")
        let renders = Renders()

        let patch = renders.render(
            VStack {
                Slider(volume.projectedValue)
            }
            .engine(following: volume.projectedValue) { _ in
                reading.wrappedValue = "\(Int((volume.wrappedValue * 100).rounded()))%"
            }
            .node)

        XCTAssertNotNil(patch.children.first?.driven?[.value], "the slider is tied all the same")

        let board = Renderer.shared.board
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        dragged(volume.number, to: 0.5)
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(volume.wrappedValue, 0.5, "the drag landed on the journey")
        XCTAssertEqual(reading.wrappedValue, "50%", "and the engine, declared first, was woken by it")
    }

    /// An engine follows a state whatever shape the host carries it in: a
    /// slider's journey is as followable as a feed's number, following being
    /// about the stamp and not about the lanes - so `Slider($v)` beside
    /// `.engine(following: $v)` is the ordinary pair it looks like.
    func testAnEngineFollowsASliderOverADouble() {
        let volume = State(wrappedValue: 0.2)
        let reading = State(wrappedValue: "")
        let renders = Renders()

        renders.render(
            Slider(volume.projectedValue)
                .engine(following: volume.projectedValue) { _ in
                    reading.wrappedValue = "\(Int((volume.wrappedValue * 100).rounded()))%"
                }
                .node)

        let board = Renderer.shared.board
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        dragged(volume.number, to: 0.5)
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(reading.wrappedValue, "50%", "the engine followed the slider's journey")
    }

    /// A value is issued ONE number however often it is asked for it: the host
    /// quotes that number back, and a second one would be a second value.
    func testACarriedStatesNumberIsIssuedOnce() {
        let value = State(wrappedValue: 0.0)

        XCTAssertEqual(value.number, value.number)
        XCTAssertNotEqual(value.number, State(wrappedValue: 0.0).number)
    }

    /// A view is a value REBUILT on every render, and the wrapper is rebuilt
    /// with it - so the storage has to be taken over, or the host would be
    /// moving a value nothing reads. One number and one value across both.
    func testACarriedStateRenderedTwiceCarriesOneNumber() {
        let renders = Renders()
        let seen = Seen()

        renders.render(Holder(seen: seen).node)
        renders.render(Holder(seen: seen, tag: 2).node)

        XCTAssertEqual(seen.numbers.count, 2, "the holder was built twice")
        XCTAssertEqual(
            seen.numbers.first, seen.numbers.last,
            "the second wrapper quotes the number the first was issued")
    }

    /// And the VALUE goes with the number: a number the host moved between two
    /// renders is where the host left it, not where the declaration says.
    func testACarriedStateKeepsWhatTheHostWroteAcrossARender() {
        let renders = Renders()
        let seen = Seen()

        renders.render(Holder(seen: seen).node)
        moved(seen.numbers[0], to: 1)
        renders.render(Holder(seen: seen, tag: 2).node)

        XCTAssertEqual(seen.values, [false, true])
    }

    /// A BINDING MADE BEFORE ITS STATE WAS ADOPTED LENDS THE ADOPTED STATE: the view built again takes the state
    /// it had, and the binding its initializer made with the fresh one carries that state on the same number - its
    /// value, a report from the control and a post landing on the one owner, a post through it waiting in the same
    /// queue as one through the owner's binding now.
    func testABindingMadeBeforeAdoptionLendsTheAdoptedState() async throws {
        let renders = Renders()
        let first = renders.render(EarlyBinding(seed: 0.2, revision: 0).node)
        let original = try XCTUnwrap(first.child("slider")?.driven?.bindings[.value]?.state)

        let fresh = EarlyBinding(seed: 0.9, revision: 1)
        let next = renders.render(fresh.node)
        // A tie that stands crosses as nothing; one sent again names its state.
        let carried = next.child("slider")?.driven?.bindings[.value]?.state ?? original

        XCTAssertEqual(fresh.owner, 0.2, "the state adopted")
        XCTAssertEqual(carried, original, "the binding carries the adopted state, on its number")
        XCTAssertEqual(fresh.borrowed.journey.destination, 0.2)

        dragged(carried, to: 0.4)
        XCTAssertEqual(fresh.owner, 0.4, "the control's report reached the owner")

        fresh.borrowed.post(0.6)
        fresh.$owner.post(0.7)
        fresh.borrowed.post(0.8)
        await settle()
        XCTAssertEqual(fresh.owner, 0.8, "the last post stands, whichever binding posted it")
    }

    /// Where the journey of the state carried under `number` is headed.
    private func destination(_ number: Int32) -> Double? {
        guard let image = Renderer.shared.storage(of: number) else { return nil }

        return JourneyLanes<Double>(carried: Renderer.shared.board.read(image, lanes: JourneyLanes<Double>.lanes))?.destination
    }

    /// A PART MADE BEFORE ADOPTION WRITES INTO THE ADOPTED WHOLE: its write keeps the other elements the owner
    /// holds now, not the ones the fresh state began with.
    func testAPartMadeBeforeAdoptionWritesIntoTheAdoptedWhole() {
        let renders = Renders()
        renders.render(EarlyPart(seed: [1, 2], revision: 0).node)
        let fresh = EarlyPart(seed: [8, 9], revision: 1)
        renders.render(fresh.node)

        XCTAssertEqual(fresh.part.wrappedValue, 1)
        fresh.part.wrappedValue = 3
        XCTAssertEqual(fresh.owner, [3, 2], "the second element the owner holds stands")
    }

    /// A CONVERSION MADE BEFORE ADOPTION FOLLOWS THE ADOPTED STATE - of one source or of several: worked out from
    /// it, and a report worked back into it.
    func testAConversionMadeBeforeAdoptionFollowsTheAdoptedState() throws {
        for multi in [false, true] {
            Renderer.shared.clearStates()
            let renders = Renders()
            renders.render(EarlyConversion(seed: 0.2, revision: 0, multi: multi).node)
            let fresh = EarlyConversion(seed: 0.9, revision: 1, multi: multi)
            let patch = renders.render(fresh.node)
            let number = try XCTUnwrap(patch.driven?.bindings[.value]?.state, "the fresh view's derived state is tied")
            let board = Renderer.shared.board
            board.cycle(now: 0, reducesMotion: false)

            XCTAssertEqual(fresh.owner, 0.2)
            XCTAssertEqual(destination(number), 20, multi ? "several sources" : "one source")

            _ = board.dirty()
            dragged(number, to: 40)
            board.cycle(now: 16, reducesMotion: false)
            board.cycle(now: 32, reducesMotion: false)
            XCTAssertEqual(fresh.owner, 0.4, accuracy: 1e-9, multi ? "several sources" : "one source")
        }
    }

    /// POSTS WAITING SINCE BEFORE ADOPTION LAND IN THE ORDER POSTED, with those through the owner: the last stands,
    /// whichever queue it waited in.
    func testPostsWaitingSinceBeforeAdoptionLandInTheOrderPosted() async {
        for earlyFirst in [false, true] {
            Renderer.shared.clearStates()
            let renders = Renders()
            let first = EarlyBinding(seed: 1, revision: 0)
            renders.render(first.node)
            let fresh = EarlyBinding(seed: 9, revision: 1)
            if earlyFirst {
                fresh.borrowed.post(0.3)
                first.borrowed.post(0.2)
            } else {
                first.borrowed.post(0.2)
                fresh.borrowed.post(0.3)
            }
            renders.render(fresh.node)
            if !earlyFirst { fresh.borrowed.post(0.4) }
            await settle()

            XCTAssertEqual(fresh.owner, earlyFirst ? 0.2 : 0.4, earlyFirst ? "the owner's post came last" : "the last post")
        }
    }

    /// A CONVERSION KEPT ACROSS BUILDS FOLLOWS ITS STATE AFTER THE BOX IT WAS MADE FROM LEAVES: the state lives on
    /// in the box built last, and the conversion is worked out from it and reports into it - made from the first
    /// box, or made before the state's box adopted the one kept and kept beyond that box.
    func testAKeptConversionFollowsItsStateAfterItsBoxLeaves() throws {
        for early in [false, true] {
            Renderer.shared.clearStates()
            let (kept, renders, board) = (Kept(), Renders(), Renderer.shared.board)
            func tree(_ revision: Int) -> Node {
                early
                    ? KeepsAnEarlyConversion(seed: revision == 0 ? 0.2 : 0.9, revision: revision, kept: kept).node
                    : KeepsItsConversion(kept: kept, revision: revision).node
            }
            // A tie that stands crosses as nothing: the number is the first patch's where the second sends none.
            let first = renders.render(tree(0))
            let second = renders.render(tree(1))
            let number = try XCTUnwrap(
                second.driven?.bindings[.value]?.state ?? first.driven?.bindings[.value]?.state, early ? "early" : "kept")
            board.cycle(now: 0, reducesMotion: false)
            XCTAssertEqual(destination(number), 20, early ? "early" : "kept")

            renders.render(tree(2))
            XCTAssertNil(kept.box, "the box the conversion was made from left")
            XCTAssertEqual(kept.current?.wrappedValue, 0.2)

            kept.current?.wrappedValue = 0.4
            board.cycle(now: 16, reducesMotion: false)
            XCTAssertEqual(destination(number), 40, early ? "early" : "kept")

            _ = board.dirty()
            dragged(number, to: 60)
            board.cycle(now: 32, reducesMotion: false)
            board.cycle(now: 48, reducesMotion: false)
            XCTAssertEqual(try XCTUnwrap(kept.current?.wrappedValue), 0.6, accuracy: 1e-9, early ? "early" : "kept")
        }
    }

    /// A VIEW RENDERED AGAIN AFTER ANOTHER INSTANCE ADOPTED ITS STATE KEEPS THAT STATE: the two boxes hold one
    /// storage, which stands for itself - a storage the element keeps is given up for nothing, itself least of all -
    /// and the conversion follows a write through either instance.
    func testAViewRenderedAgainAfterAnotherAdoptedItsStateKeepsIt() throws {
        let renders = Renders()
        let (first, second) = (OwnedSlider(revision: 0), OwnedSlider(revision: 1))
        let number = try XCTUnwrap(renders.render(first.node).driven?.bindings[.value]?.state)
        renders.render(second.node)
        XCTAssertTrue(first.$value.storage === second.$value.storage, "the second adopted the first's state")

        // Tied as it stands, the state crosses as nothing; one sent again names its number.
        let again = renders.render(first.node)
        let tied = again.driven?.bindings[.value]?.state ?? number
        XCTAssertTrue(first.$value.storage.standsFor === first.$value.storage, "the state stands for itself")
        XCTAssertTrue(first.$value.storage === second.$value.storage, "both hold it still")

        first.value = 0.4
        Renderer.shared.board.cycle(now: 0, reducesMotion: false)
        XCTAssertEqual(destination(tied), 40)

        second.value = 0.5
        Renderer.shared.board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(destination(tied), 50, "a write through the other instance")
    }

    /// POSTS TO THE WHOLE AND TO ITS PARTS, WAITING ACROSS ADOPTION, LAND IN THE ORDER POSTED: a change over what
    /// the one before left, and a whole posted later replacing the parts posted before it, not a change after it.
    func testPostsToTheWholeAndItsPartsLandInTheOrderPosted() async {
        let renders = Renders()
        let first = EarlyList(seed: [1, 2], revision: 0)
        renders.render(first.node)
        var fresh = EarlyList(seed: [8, 9], revision: 1)
        first.early.post([10, 20])
        fresh.early[0].post { $0 + 1 }
        first.early[1].post { $0 * 2 }
        fresh.early.post { $0.map { $0 + 100 } }
        renders.render(fresh.node)
        await settle()
        XCTAssertEqual(fresh.value, [111, 140])

        Renderer.shared.clearStates()
        let again = Renders()
        let before = EarlyList(seed: [1, 2], revision: 0)
        again.render(before.node)
        fresh = EarlyList(seed: [8, 9], revision: 1)
        fresh.early[0].post(90)
        before.early[1].post { $0 * 10 }
        again.render(fresh.node)
        before.early.post([3, 4])
        fresh.early[1].post { $0 + 1 }
        await settle()
        XCTAssertEqual(fresh.value, [3, 5])
    }

    /// A BINDING IS BORROWED, AND THE STATE WALK STOPS AT IT: the state behind
    /// a binding belongs to whoever handed it over, is adopted by path on that
    /// owner, and is never counted as the child's own - whether the child
    /// drives a property from it, follows it, or reads it. The walk stops by
    /// the MARK, `BorrowedState`, and not by the shape of the wrapper, so a
    /// field added to `Binding` cannot open it to the walk.
    func testABindingIsBorrowedAndTheStateWalkStopsAtIt() {
        let level = State(wrappedValue: 0.5)

        XCTAssertEqual(
            stateParts(in: Rider(level: level.projectedValue)).boxes.count, 0,
            "a view holding a binding owns none of the state behind it")
    }

    // MARK: - What a message says about it

    /// AN EMPTIED DRIVEN SET LEAVES A CHILD ELEMENT. A driven modifier writes
    /// nothing into `props`, so a child whose only change is which states it
    /// ties has no other field to be heard by - and a patch that counted every
    /// field but `driven` as empty dropped it at the parent, leaving the host
    /// tied to a state the tree had stopped naming.
    func testADrivenModifierDroppedFromAChildUntiesIt() {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()

        renders.render(VStack { Plain().opacity(fade.projectedValue).id("plain") }.node)
        let patch = renders.render(VStack { Plain().id("plain") }.node)

        let child = patch.children.first
        XCTAssertNotNil(child, "the child whose tie went has to be in the message")
        XCTAssertEqual(child?.driven?.isEmpty, true, "and what it says is: no states tied")
    }

    /// A JOURNEY ON A STATE NOTHING WEARS ANSWERS AT ONCE. A number is issued
    /// when an element registers the state, so a state without one has nobody
    /// to walk it - and a waiter booked on it would wait for good. It answers
    /// that it arrived, and the value is at the target for whichever view is
    /// described next.
    func testAJourneyOnAStateNothingWearsAnswersAtOnce() throws {
        let fade = State(wrappedValue: 1.0)
        let arrival = fade.projectedValue.journey.move(to: 0.1, .eased(.milliseconds(400), curve: .cubicOut))

        XCTAssertEqual(arrival.ended, true, "it arrived as it was sent")
        XCTAssertEqual(fade.projectedValue.journey.value, 0.1, "the value is at the target")
        XCTAssertEqual(fade.wrappedValue, 0.1, "and going nowhere else")
    }

    /// A DRIVEN STATE WRITTEN ON A COMPOSED VIEW IS ABOUT THAT VIEW, and reaches
    /// the element its body ends at.
    ///
    /// A composed view has no node of its own, so everything written on it is
    /// kept on a placeholder and carried onto what the body built. A
    /// registration left behind there would name a control nothing holds: the
    /// modifier would compile, the property would never be written, and
    /// nothing anywhere would say so.
    func testADrivenPropertyOnAComposedViewReachesItsElement() {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()

        let patch = renders.render(Plain().opacity(fade.projectedValue).id("plain").node)

        XCTAssertEqual(
            patch.driven?[.opacity],
            HostStateBinding(state: fade.number, mode: .inOut, kind: .property, laneKind: .number))
    }

    /// A scroller handed its offset registers it as a JOURNEY both ways - one
    /// point, walked by the host on a write and written by it on a report -
    /// and no handler at all: there is nothing to run on this side.
    func testAScrollerNamesTheStateItReportsInto() {
        let offset = State(wrappedValue: Point.zero)
        let renders = Renders()

        let patch = renders.render(
            ScrollView { Text("x") }
                .axes(.horizontal)
                .scrollOffset(offset.projectedValue)
                .node)

        XCTAssertEqual(
            patch.driven?[.scrollOffset],
            HostStateBinding(state: offset.number, mode: .inOut, kind: .property, laneKind: .number))
        XCTAssertNil(patch.events, "the offset is carried, and nothing hears it besides")
    }

    /// A view whose drag is written into values says both numbers.
    func testADraggedViewNamesTheValuesItIsWrittenInto() {
        let across = State(wrappedValue: 0.0)
        let down = State(wrappedValue: 0.0)

        let node = Rectangle()
            .fill(Color(hex: 0x000000))
            .panX(across.projectedValue)
            .panY(down.projectedValue)
            .node

        XCTAssertEqual(node.props[.panXChannel], .number(Double(across.number)))
        XCTAssertEqual(node.props[.panYChannel], .number(Double(down.number)))
    }

    // MARK: - The law a driven value travels under

    /// `.inherited` on a driven value means THE ELEMENT'S own law, and this
    /// side is the only one that can say what that is.
    ///
    /// The host knows what the application answers and no more: an element's
    /// `.motion(_:_:)` is a plan read per KIND of value, which never crosses.
    /// So an element told `.motion(.spring())` carries its driven opacity on
    /// the spring, exactly as it carries the opacity beside it that the tree
    /// describes.
    func testADrivenValueTravelsUnderItsElementsOwnLaw() {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()

        renders.render(Text("x").motion(.spring(response: .milliseconds(450), damping: 0.7))
            .opacity(fade.projectedValue).id("one").node)

        XCTAssertEqual(
            standing(fade.number, as: JourneyLanes<Double>.self)?.motion,
            .spring(response: .milliseconds(450), damping: 0.7))
    }

    /// And the IMAGE goes on saying what the author wrote. `.inherited` is a
    /// request answered afresh on every crossing, which is what lets an
    /// element described later change the answer for a value already standing.
    func testTheValueItselfStillSaysInherited() {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()

        renders.render(Text("x").motion(.spring()).opacity(fade.projectedValue).id("one").node)

        XCTAssertEqual(fade.projectedValue.journey.motion, .inherited)
    }

    /// An element given a NEW law answers for a value it was already driving:
    /// the resolution is the crossing's, not the write's.
    func testANewLawOnTheElementReachesAValueAlreadyStanding() {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()

        renders.render(Text("x").motion(.eased(.milliseconds(90), curve: .linear))
            .opacity(fade.projectedValue).id("one").node)
        renders.render(Text("x").motion(.eased(.milliseconds(700), curve: .cubicIn))
            .opacity(fade.projectedValue).id("one").node)

        XCTAssertEqual(
            standing(fade.number, as: JourneyLanes<Double>.self)?.motion,
            .eased(.milliseconds(700), curve: .cubicIn))
    }

    /// A rule naming COLORS answers a driven color, which the property alone
    /// cannot say - `background` is in no group, and what puts it in one
    /// is the value it carries.
    func testARuleNamingColorsAnswersADrivenColor() {
        let tint = State(wrappedValue: Color(hex: 0x102030))
        let renders = Renders()

        renders.render(Text("x").motion(.none).motion(.eased(.milliseconds(640), curve: .cubicIn), .color)
            .background(tint.projectedValue).id("one").node)

        XCTAssertEqual(
            standing(tint.number, as: JourneyLanes<Color>.self)?.motion,
            .eased(.milliseconds(640), curve: .cubicIn))
    }

    /// A value NO element drives holds `.inherited` as its law - there being
    /// no element to ask - until one that drives it says its own.
    func testAValueNobodyDrivesHoldsInherited() throws {
        let loose = State(wrappedValue: 1.0)

        // The journey's image, which is what a number is issued against here:
        // a state nothing has walked has none until something asks.
        _ = loose.projectedValue.journeyImage

        XCTAssertNotNil(Renderer.shared.storage(of: loose.number), "a state rides the number")
        let image = try XCTUnwrap(Renderer.shared.board.whole(loose.number))

        XCTAssertEqual(
            JourneyLanes<Double>(carried: StateImage.carried(of: image, lanes: StateValueLanes.own))?.motion,
            .inherited)
    }

    /// A child handed the binding writes the owner's value and reads it back:
    /// `@Binding` is the same image in another view, handed over by the
    /// memberwise initializer - `Rider(level: $level)`.
    func testAChildHandedTheBindingSharesTheOwnersImage() {
        let level = State(wrappedValue: 0.2)
        let rider = Rider(level: level.projectedValue)

        rider.bump()

        XCTAssertEqual(level.wrappedValue, 1.2, "the child's write moved the owner's value")

        level.wrappedValue = 5

        XCTAssertEqual(rider.level, 5, "and the owner's write is what the child reads")
        XCTAssertEqual(rider.$level.number, level.number, "one image, one number")
    }

    /// A PART of a carried state is not itself driven: the image is the whole
    /// value, and no message can say that a property rides one lane of it.
    ///
    /// The part still reads and writes - through the whole - so what this pins
    /// is which ROAD it takes, not whether it works: the whole has an image, and
    /// a part of it is a proxy, which no driven modifier accepts.
    func testAPartOfACarriedStateIsNotDriven() {
        let room = State(wrappedValue: Rect(0, 0, 0, 0))

        let whole: Binding<Rect> = room.projectedValue
        let part: StatePart<Double> = whole.width

        part.wrappedValue = 90

        XCTAssertEqual(room.wrappedValue.width, 90, "the part writes through the whole")
        XCTAssertEqual(part.wrappedValue, 90, "and reads it back")
    }

    /// One view value placed twice has one box for both places, so the places share its state: a write in one
    /// shows in the other, and the box keeps one storage across renders.
    func testAValueStandingInTwoPlacesSharesItsState() throws {
        let renders = Renders()
        let tally = Tally()

        let patch = renders.render(stack([tally.node, tally.node], id: "root"))

        XCTAssertEqual(patch.child(.auto(1))?.props[.text], .string("0"))
        XCTAssertEqual(patch.child(.auto(2))?.props[.text], .string("0"))

        XCTAssertTrue(renders.fire(try XCTUnwrap(patch.child(.auto(1))?.events?["clicked"])))
        let again = renders.render(
            stack([tally.node, tally.node], id: "root"), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(again.child(.auto(1))?.props[.text], .string("1"), "the first place shows the write")
        XCTAssertEqual(again.child(.auto(2))?.props[.text], .string("1"), "and so does the second: one state")
    }

    /// A view held in a property and placed once: its holder's walk meets its box first, and the view's own place
    /// is under the holder - one state, one place.
    func testAViewHeldInAPropertyStandsOnceUnderItsHolder() throws {
        let renders = Renders()

        let patch = renders.render(stack([Holding().node], id: "root"))
        let button = try XCTUnwrap(patch.child(.auto(1))?.child(.auto(2)))

        XCTAssertEqual(button.type, .button)
        XCTAssertEqual(button.props[.text], .string("counted 0"))

        XCTAssertTrue(renders.fire(try XCTUnwrap(button.events?["clicked"])))
        let again = renders.render(stack([Holding().node], id: "root"), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(again.child(.auto(1))?.child(.auto(2))?.props[.text], .string("counted 1"))
    }

    /// `update(_:)` on a carried state MOVES the value, which is the whole of
    /// what a member on this declaration has to do.
    ///
    /// A carried state keeps one image and nothing else, so there is no second
    /// storage for a read-change-write to land in: what this writes is what the
    /// next read answers with.
    func testAChangePostedToACarriedStateMovesTheValue() async {
        let offset = State(wrappedValue: 12.0)

        offset.projectedValue.post { $0 + 30 }
        await settle()

        XCTAssertEqual(offset.wrappedValue, 42, "the write reached the image")
        XCTAssertEqual(offset.wrappedValue, 42, "and every road to it reads the same")
    }

}
