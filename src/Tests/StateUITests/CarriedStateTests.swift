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
// The mechanism is in Core/StateValue.swift; the host's half - which runs the
// cycle on the platform's own frames and writes the values onto the controls -
// is StateUI.Runtime's StateCycle.cs.

import XCTest
@testable import StateUI

/// A view ON a bus somebody else declared, reading it - so a test can see that
/// reading one records nothing, and that `@Binding` is how a bus is handed down.
private struct Follower: ContentView {
    @Binding var value: Double
    let builds: Builds

    var content: Element {
        builds.count += 1
        return label("at \(value)")
    }
}

/// A view ON a bus somebody else declared, writing it - which is what `@Binding`
/// is for, and the shape a child takes a bus in.
private struct Rider: ContentView {
    @Binding var level: Double

    var content: Element { label("riding") }

    /// A handler's write, as a child on the bus makes one.
    func bump() { level += 1 }
}

/// A view holding a driven state of its OWN, so a test can watch the wrapper a second
/// render builds take over the storage the first one made.
private struct Holder: ContentView {
    @State var offset = 0.0
    let seen: Seen

    var content: Element {
        seen.numbers.append($offset.number ?? -1)
        seen.values.append(offset)
        return label("held")
    }
}

/// A composed view with nothing of its own written on it, so a test can write
/// a driven state ON it and look for the registration on the element its body ends at.
private struct Plain: ContentView {
    var content: Element { Label("plain") }
}

/// What each render of the holder saw. A class, for the same reason.
private final class Seen {
    var numbers: [Int32] = []
    var values: [Double] = []
}

/// Counts builds. A class, so the walk that collects state boxes leaves it
/// alone.
private final class Builds {
    var count = 0
}

final class CarriedStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    // MARK: - The value

    /// Writing one asks for no render and names no change - which is the whole
    /// of what makes it affordable to move with a finger.
    func testWritingABusAsksForNoRender() {
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

        renders.render(stack([Follower(value: value.projectedValue, builds: builds).body], id: "root"))
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

        renders.render(stack([Rider(level: value.projectedValue).body], id: "root"))
        Renderer.shared.clearInvalidation()

        value.wrappedValue = 12

        XCTAssertFalse(Renderer.shared.needsRender, "nothing read it at build")
        XCTAssertTrue(Renderer.shared.pendingChanges.isEmpty)
    }

    /// A JOURNEY'S OWN MACHINERY MAKES NO READER, wherever it runs.
    ///
    /// `animateTo` reads the value it is about to move, and a completion
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
        let dip = State(wrappedValue: AnimatedValue(1.0))
        let renders = Renders()

        renders.render(stack([Border { Label("x") }.scale(dip.projectedValue).body], id: "root"))
        Renderer.shared.clearInvalidation()

        // A build's scope, and the machinery of a write running inside it -
        // which is where a resumed handler runs when a completion is answered
        // mid-render.
        let (_, reads) = ReadScope.collect {
            dip.projectedValue.setPoint = 0.96
            dip.projectedValue.snap(to: 0.96)
            dip.projectedValue.stop()
        }

        XCTAssertTrue(reads.isEmpty, "a write reading what it changes is not a dependency")
        XCTAssertFalse(dip.storage.readAtBuild, "and it is not a read at build either")
    }

    /// The host says where it stands by the number it was issued, and the
    /// value is then what anything reading it sees - a handler asking where
    /// the run is, and the arithmetic itself.
    func testTheHostMovesItByItsNumber() {
        let value = State(wrappedValue: 0.0)
        let number = value.number

        moved(number, to: 91.5)

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
            Follower(value: value.projectedValue, builds: builds).body,
            Rider(level: value.projectedValue).body,
        ], id: "root"))
        Renderer.shared.clearInvalidation()

        moved(value.number, to: 12)

        XCTAssertTrue(Renderer.shared.needsRender, "a body printed it, so the host's write renders")
        renders.revisit(changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(builds.count, 2, "the reader is built again, and only the reader")
        XCTAssertEqual(value.wrappedValue, 12)
    }

    /// And at the state's own cadence: `.every(ms)` holds the host's writes to
    /// one render a window, exactly as it holds this side's.
    func testAHostWriteAsksAtTheStatesCadence() {
        let value = State(wrappedValue: 0.0)
        let builds = Builds()
        let renders = Renders()

        value.projectedValue.asks = .every(100_000)
        renders.render(stack([Follower(value: value.projectedValue, builds: builds).body], id: "root"))
        Renderer.shared.clearInvalidation()

        moved(value.number, to: 1)
        XCTAssertTrue(Renderer.shared.needsRender, "the first write in a window asks at once")
        Renderer.shared.clearInvalidation()

        moved(value.number, to: 2)
        XCTAssertFalse(Renderer.shared.needsRender, "the second is inside the window")
        XCTAssertEqual(value.wrappedValue, 2, "and the value is written where it is read all the same")
    }

    /// `Slider($volume)` over a plain `Double` is HANDED OVER: the host walks
    /// the value as a journey, the slider reads nothing at build, an
    /// assignment moves the destination alone, and a drag is the host's write
    /// onto value and destination together.
    func testASliderOverADoubleIsCarriedAsAJourney() {
        let volume = State(wrappedValue: 0.25)
        let renders = Renders()

        let patch = renders.render(Slider(volume.projectedValue).body)

        XCTAssertNil(patch.props[.value], "nothing is described: the value rides the image")
        XCTAssertEqual(patch.driven?[.value]?.mode, .inOut)
        XCTAssertEqual(patch.driven?[.value]?.kind, .property)

        let board = Renderer.shared.board(of: volume.image)
        board.cycle(now: 0, reducesMotion: false)
        _ = board.dirty()

        volume.wrappedValue = 0.75
        board.cycle(now: 16, reducesMotion: false)

        let sent = board.dirty().first { $0.number == volume.number }

        XCTAssertEqual(volume.wrappedValue, 0.75, "the state answers where it is going")
        XCTAssertNotEqual(sent.map { $0.mask & AnimatedValue<Double>.mask(of: .setPoint) }, 0,
                          "the destination crossed")
        XCTAssertEqual(sent.map { $0.mask & AnimatedValue<Double>.mask(of: .value) }, 0,
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
            Follower(value: volume.projectedValue, builds: builds).body,
            Slider(volume.projectedValue).body,
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

        let volume = State(wrappedValue: 0.0)

        _ = volume.projectedValue.journeyImage

        XCTAssertNil(volume.projectedValue.image, "carried as a journey, so not as the value")
        XCTAssertNotNil(volume.projectedValue.followed, "and an engine follows it all the same")
    }

    /// `.engine(following: $v)` on a container runs BEFORE the container's
    /// content hands `$v` to the slider inside it - so the image an engine is
    /// made to follow, which the host has not been told of, is reshaped into
    /// the slider's journey rather than refused, and the engine follows the
    /// same object throughout.
    func testAnEngineFollowingFirstLeavesTheSliderItsJourney() {
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
            .body)

        XCTAssertNotNil(patch.children.first?.driven?[.value], "the slider is tied all the same")

        let board = Renderer.shared.board(of: volume.image)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        dragged(volume.number, to: 0.5)
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(volume.wrappedValue, 0.5, "the drag landed on the journey")
        XCTAssertEqual(reading.wrappedValue, "50%", "and the engine, made first, followed it")
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
                .body)

        let board = Renderer.shared.board(of: volume.image)
        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        dragged(volume.number, to: 0.5)
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(reading.wrappedValue, "50%", "the engine followed the slider's journey")
    }

    /// A value is issued ONE number however often it is asked for it: the host
    /// quotes that number back, and a second one would be a second value.
    func testABusNumberIsIssuedOnce() {
        let value = State(wrappedValue: 0.0)

        XCTAssertEqual(value.number, value.number)
        XCTAssertNotEqual(value.number, State(wrappedValue: 0.0).number)
    }

    /// A view is a value REBUILT on every render, and the wrapper is rebuilt
    /// with it - so the storage has to be taken over, or the host would be
    /// moving a value nothing reads. One number and one value across both.
    func testABusRenderedTwiceCarriesOneNumber() {
        let renders = Renders()
        let seen = Seen()

        renders.render(Holder(seen: seen).body)
        renders.render(Holder(seen: seen).body)

        XCTAssertEqual(seen.numbers.count, 2, "the holder was built twice")
        XCTAssertEqual(
            seen.numbers.first, seen.numbers.last,
            "the second wrapper quotes the number the first was issued")
    }

    /// And the VALUE goes with the number: a number the host moved between two
    /// renders is where the host left it, not where the declaration says.
    func testABusKeepsWhatTheHostWroteAcrossARender() {
        let renders = Renders()
        let seen = Seen()

        renders.render(Holder(seen: seen).body)
        moved(seen.numbers[0], to: 91.5)
        renders.render(Holder(seen: seen).body)

        XCTAssertEqual(seen.values, [0, 91.5])
    }

    /// A LINK IS BORROWED, AND THE STATE WALK STOPS AT IT: the bus behind a link
    /// belongs to whoever handed it over, is adopted by path on that owner, and
    /// is never counted as the child's own. The walk stops by the MARK - `Link`
    /// is a `BorrowedState`, as `Binding` is - and not by the shape of the
    /// wrapper, so a field added to `Link` cannot open it to the walk.
    func testALinkIsBorrowedAndTheStateWalkStopsAtIt() {
        let level = State(wrappedValue: 0.5)

        XCTAssertTrue(level.projectedValue is BorrowedState, "a link is marked, as a binding is")
        XCTAssertEqual(
            stateParts(in: Rider(level: level.projectedValue)).boxes.count, 0,
            "a view holding a link owns none of the state behind it")
    }

    // MARK: - What a message says about it

    /// AN EMPTIED DRIVEN SET LEAVES A CHILD ELEMENT. A driven modifier writes
    /// nothing into `props`, so a child whose only change is which states it
    /// ties has no other field to be heard by - and a patch that counted every
    /// field but `driven` as empty dropped it at the parent, leaving the host
    /// tied to a bus the tree had stopped naming.
    func testADrivenModifierDroppedFromAChildUntiesIt() {
        let fade = State(wrappedValue: AnimatedValue(1.0))
        let renders = Renders()

        renders.render(VStack { Plain().opacity(fade.projectedValue).id("plain") }.body)
        let patch = renders.render(VStack { Plain().id("plain") }.body)

        let child = patch.children.first
        XCTAssertNotNil(child, "the child whose tie went has to be in the message")
        XCTAssertEqual(child?.driven?.isEmpty, true, "and what it says is: no states tied")
    }

    /// A JOURNEY ON A BUS NOTHING WEARS ANSWERS AT ONCE. A number is issued
    /// when an element registers the state, so a bus without one has nobody
    /// to walk it - and a waiter booked on it would wait for good. It answers
    /// that it arrived, and the value is at the target for whichever view is
    /// described next.
    func testAJourneyOnAStateNothingWearsAnswersAtOnce() async throws {
        let fade = State(wrappedValue: AnimatedValue(1.0))
        let link = fade.projectedValue

        let arrived = try await withThrowingTaskGroup(of: Bool?.self) { group in
            group.addTask { try await link.animateTo(0.1, .eased(400, .cubicOut)) }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                return nil
            }
            let first = try await group.next() ?? nil
            group.cancelAll()
            return first
        }

        XCTAssertEqual(arrived, true, "answered, and answered that it arrived")
        XCTAssertEqual(fade.wrappedValue.value, 0.1, "the value is at the target")
        XCTAssertEqual(fade.wrappedValue.setPoint, 0.1, "and going nowhere else")
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
        let fade = State(wrappedValue: AnimatedValue(1.0))
        let renders = Renders()

        let patch = renders.render(Plain().opacity(fade.projectedValue).id("plain").body)

        XCTAssertEqual(
            patch.driven?[.opacity],
            StateEntry(number: fade.number, mode: .inOut, kind: .property))
    }

    /// A scroller told to report into a driven state says so as a number, and
    /// no handler at all - there is nothing to run on this side.
    func testAScrollerNamesTheStateItReportsInto() {
        let value = State(wrappedValue: 0.0)

        let node = ScrollView { Label("x") }
            .orientation(.horizontal)
            .scrollX(value.projectedValue)
            .body

        XCTAssertEqual(node.props[.scrollXChannel], .number(Double(value.number)))
        XCTAssertNil(node.events[.scrollXChanged])
    }

    /// A view whose drag is written into values says both numbers.
    func testADraggedViewNamesTheValuesItIsWrittenInto() {
        let across = State(wrappedValue: 0.0)
        let down = State(wrappedValue: 0.0)

        let node = BoxView(Color("#000000")).panX(across.projectedValue).panY(down.projectedValue).body

        XCTAssertEqual(node.props[.panXChannel], .number(Double(across.number)))
        XCTAssertEqual(node.props[.panYChannel], .number(Double(down.number)))
    }

    // MARK: - The reader

    /// A `ScrollReader` lays an empty scroller over what it holds, as long as
    /// the room plus how far the run goes beyond it, reporting into the
    /// state.
    func testAScrollReaderReportsIntoItsState() {
        let across = State(wrappedValue: 0.0)
        let renders = Renders()

        let patch = renders.render(
            ScrollReader(across: 540) { Label("under") }
                .scrollX(across.projectedValue)
                .snapInterval(90)
                .id("reader")
                .body)

        func scroller(_ patch: Patch) -> Patch? {
            if patch.type == .scrollView { return patch }

            for child in patch.children {
                if let found = scroller(child) { return found }
            }

            return nil
        }

        let found = scroller(patch)

        XCTAssertEqual(found?.props[.scrollXChannel], .number(Double(across.number)))
        XCTAssertEqual(found?.props[.snapInterval], .number(90))
        XCTAssertEqual(found?.props[.orientation]?.enumeration, ScrollOrientation.horizontal.rawValue)
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
        let fade = State(wrappedValue: AnimatedValue(1.0))
        let renders = Renders()

        renders.render(Label("x").motion(.spring(response: 450, damping: 0.7))
            .opacity(fade.projectedValue).id("one").body)

        XCTAssertEqual(
            standing(fade.number, as: AnimatedValue<Double>.self)?.motion,
            .spring(response: 450, damping: 0.7))
    }

    /// And the IMAGE goes on saying what the author wrote. `.inherited` is a
    /// request answered afresh on every crossing, which is what lets an
    /// element described later change the answer for a value already standing.
    func testTheValueItselfStillSaysInherited() {
        let fade = State(wrappedValue: AnimatedValue(1.0))
        let renders = Renders()

        renders.render(Label("x").motion(.spring()).opacity(fade.projectedValue).id("one").body)

        XCTAssertTrue(fade.projectedValue.motion.isInherited)
    }

    /// An element given a NEW law answers for a value it was already driving:
    /// the resolution is the crossing's, not the write's.
    func testANewLawOnTheElementReachesAValueAlreadyStanding() {
        let fade = State(wrappedValue: AnimatedValue(1.0))
        let renders = Renders()

        renders.render(Label("x").motion(.eased(90, .linear))
            .opacity(fade.projectedValue).id("one").body)
        renders.render(Label("x").motion(.eased(700, .cubicIn))
            .opacity(fade.projectedValue).id("one").body)

        XCTAssertEqual(
            standing(fade.number, as: AnimatedValue<Double>.self)?.motion,
            .eased(700, .cubicIn))
    }

    /// A rule naming COLOURS answers a driven colour, which the property alone
    /// cannot say - `backgroundColor` is in no group, and what puts it in one
    /// is the value it carries.
    func testARuleNamingColoursAnswersADrivenColour() {
        let tint = State(wrappedValue: AnimatedValue(Color("#102030")))
        let renders = Renders()

        renders.render(Label("x").motion(.none).motion(.eased(640, .cubicIn), .colour)
            .backgroundColor(tint.projectedValue).id("one").body)

        XCTAssertEqual(
            standing(tint.number, as: AnimatedValue<Color>.self)?.motion,
            .eased(640, .cubicIn))
    }

    /// A value NO element drives says `.inherited` on the wire still, and the
    /// host answers it with the application's - there being no element to ask.
    func testAValueNobodyDrivesCrossesAsInherited() {
        let loose = State(wrappedValue: AnimatedValue(1.0))

        XCTAssertEqual(standing(loose.number, as: AnimatedValue<Double>.self)?.motion, .inherited)
    }

    /// A view ON the bus writes the owner's value and reads it back: `@Binding` is
    /// the same image under another declaration, handed over by the memberwise
    /// initializer exactly as a binding is - `Rider(level: $level)`.
    func testAViewOnTheBusSharesTheOwnersImage() {
        let level = State(wrappedValue: 0.2)
        let rider = Rider(level: level.projectedValue)

        rider.bump()

        XCTAssertEqual(level.wrappedValue, 1.2, "the child's write moved the owner's value")

        level.wrappedValue = 5

        XCTAssertEqual(rider.level, 5, "and the owner's write is what the child reads")
        XCTAssertEqual(rider.$level.number, level.number, "one image, one number")
    }

    /// A PART of a bus is not itself driven: the image is the whole value, and
    /// no message can say that a property rides one lane of it.
    ///
    /// The part still reads and writes - through the whole, as any derived
    /// binding does - so what this pins is which ROAD it takes, not whether it
    /// works: the whole is a `Link`, and a part of it comes back as a
    /// described `Binding`, the type no driven modifier accepts.
    func testAPartOfABusIsNotDriven() {
        let room = State(wrappedValue: Rect(0, 0, 0, 0))

        let whole: Binding<Rect> = room.projectedValue
        let part: Binding<Double> = whole.width

        part.wrappedValue = 90

        XCTAssertEqual(room.wrappedValue.width, 90, "the part writes through the whole")
        XCTAssertEqual(part.wrappedValue, 90, "and reads it back")
    }

    /// `update(_:)` on a bus MOVES the value, which is the whole of what a
    /// member on this declaration has to do.
    ///
    /// A bus keeps one image and nothing else, so there is no second storage
    /// for a read-change-write to land in: what this writes is what the next
    /// read answers with.
    func testUpdatingABusMovesTheValue() {
        let offset = State(wrappedValue: 12.0)

        offset.update { $0 + 30 }

        XCTAssertEqual(offset.wrappedValue, 42, "the write reached the image")
        XCTAssertEqual(offset.get(), 42, "and every road to it reads the same")
    }

}
