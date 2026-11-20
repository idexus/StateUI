// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The journey of a walked state, and what `$x.journey` offers.
//
// A state is DISCRETE - reading it answers the destination, writing it sends the value there - and its journey is a
// HANDLE to how the host shows it between two destinations: the sample of a frame, the motion the value travels
// under, and the road to send it somewhere and wait. What these pin is that surface, the motion's two homes (the
// declaration and the lanes) and what a state an engine animates leaves to the engine.
//
// A channel's life is ChannelLifetimeTests', the engine that animates EngineMotionTests', what follows a journey
// PresentationEngineTests'.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class JourneyTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// A HANDLE AND NOTHING MORE: a state declared as a plain number has a journey, which says its motion and has
    /// no sample while nothing shows the state.
    func testEveryWalkedStateHasAJourney() {
        let rotation = State(wrappedValue: 2.0)
        let journey = rotation.projectedValue.journey

        XCTAssertNil(journey.sample, "nothing shows it")
        XCTAssertEqual(journey.motion, .inherited, "the application's, until said")
        XCTAssertFalse(rotation.storage.carried, "reading the handle carried nothing")
    }

    /// `snap(to:)` says all three at once - here, going nowhere, standing still: the host is handed the value at
    /// the place it was put, with no way left to travel and no speed.
    func testSnappingSaysHereGoingNowhereAndStandingStill() throws {
        let box = State(wrappedValue: 0.0)
        let journey = box.projectedValue.journey
        Renders().render(Rectangle().translationX(box.projectedValue).node)

        box.wrappedValue = 400
        journey.snap(to: 240)
        Renderer.shared.board.cycle(now: 16, reducesMotion: false)

        let (_, handed) = try XCTUnwrap(HostAnimatorReport.standing(box.number))
        XCTAssertEqual(handed.value, [240], "on the screen")
        XCTAssertEqual(handed.destination, [240], "and going nowhere else")
        XCTAssertEqual(handed.velocity, [0], "and not moving")
        XCTAssertEqual(box.wrappedValue, 240)
    }

    /// WHERE A THROW REACHES: as far as the value's speed for the motion's length over how steeply the motion sets
    /// out - a glide as `cubicOut` does, an eased motion on its curve; standing still, or under no motion, where it is.
    func testWhereAThrowReaches() throws {
        let offset = State(wrappedValue: Point(x: 0, y: 0))
        let journey = offset.projectedValue.journey
        XCTAssertNil(journey.reach(.glide(longest: .milliseconds(900))), "nothing shows it: nothing carries it")

        Renders().render(ScrollView { Text("a") }.scrollOffset(offset.projectedValue).node)
        let (binding, standing) = try XCTUnwrap(HostAnimatorReport.standing(offset.number))
        let frame = { (velocity: [Double]) in
            HostBoundary.report(
                HostJourney(
                    value: [100, 20], destination: [100, 20], velocity: velocity, motion: standing.motion,
                    completion: nil, stopped: 0),
                updating: .frame, through: binding, at: 16)
        }
        XCTAssertTrue(frame([600, -300]))

        let glided = try XCTUnwrap(journey.reach(.glide(longest: .milliseconds(900))))
        XCTAssertEqual(glided.x, 100 + 600 * 0.9 / 3, accuracy: 0.1, "a glide sets out as cubicOut does")
        XCTAssertEqual(glided.y, 20 - 300 * 0.9 / 3, accuracy: 0.1)
        let eased = try XCTUnwrap(journey.reach(.eased(.milliseconds(400), curve: .linear)))
        XCTAssertEqual(eased.x, 100 + 600 * 0.4, accuracy: 0.1)
        XCTAssertEqual(journey.reach(.none), Point(x: 100, y: 20), "no motion carries it")

        XCTAssertTrue(frame([0, 0]))
        XCTAssertEqual(journey.reach(.glide(longest: .milliseconds(900))), Point(x: 100, y: 20), "still, where it is")
    }

    /// A STATE NOTHING SHOWS IS WHERE IT IS WRITTEN; SHOWN, A WRITE MOVES THE DESTINATION ALONE. With no element
    /// showing the state nothing walks it, so a write is the whole of it - and once an element shows it, a write
    /// moves the destination and the host walks the value there.
    func testAStateNothingShowsIsWhereItIsWritten() throws {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()

        fade.wrappedValue = 0.2
        XCTAssertEqual(fade.wrappedValue, 0.2)
        XCTAssertNil(fade.projectedValue.journey.sample, "nobody walks it")

        renders.render(Rectangle().opacity(fade.projectedValue).node)
        fade.wrappedValue = 0.9
        Renderer.shared.board.cycle(now: 16, reducesMotion: false)

        let (_, handed) = try XCTUnwrap(HostAnimatorReport.standing(fade.number))
        XCTAssertEqual(handed.destination, [0.9], "the destination moved")
        XCTAssertEqual(handed.value, [0.2], "and the value waits for the host to walk it")
        _ = renders
    }

    /// A WRITE LAYS ONLY ITS PART. A color read back through its type is eight
    /// bits a channel, and the host reports lanes between them: a stop or a move
    /// that laid the whole journey again would say the value and the speed moved,
    /// and the host would start over from them - Stop in the Gallery's At the same
    /// time let the wash travel on to where it had been going.
    func testAJourneyWriteLaysOnlyItsPart() throws {
        let wash = State(wrappedValue: Color(hex: 0x7C3AED))
        Renders().render(Rectangle().background(wash.projectedValue).node)
        let image = try XCTUnwrap(wash.storage.walkedImage())
        let board = Renderer.shared.board
        typealias Lanes = JourneyLanes<Color>

        // The host reports a frame on its way: lanes no eight bits say.
        guard case .lanes(var lanes) = board.read(image, lanes: Lanes.lanes) else { return XCTFail("no journey") }
        for lane in Lanes.range(of: .value).lowerBound..<Lanes.range(of: .velocity).upperBound
        where !Lanes.range(of: .destination).contains(lane) {
            lanes[lane] += 0.0137
        }
        board.told(StateImage.bytes(of: .lanes(lanes)), mask: Lanes.mask(of: .value) | Lanes.mask(of: .velocity), to: image)

        let beforeStop = image.pendingMask
        wash.projectedValue.journey.stop()
        XCTAssertEqual(image.pendingMask & ~beforeStop, Lanes.mask(of: .stopped), "a stop lays its counter alone")

        let beforeMove = image.pendingMask
        wash.projectedValue.journey.move(to: Color(hex: 0xEA580C), .eased(.milliseconds(400)))
        let moved = image.pendingMask & ~beforeMove
        XCTAssertEqual(moved & (Lanes.mask(of: .value) | Lanes.mask(of: .velocity)), 0, "a move leaves the value and the speed")
        XCTAssertNotEqual(moved & Lanes.mask(of: .destination), 0, "and lays where it goes")
    }

    /// A MOVE LAYS ONLY THE LANES IT CHANGES, so the host leaves another lane's travel as it was; a move to where
    /// every lane is going already lays them all, a fresh journey its waiter hears end.
    func testAMoveLaysOnlyTheLanesItChanges() throws {
        let offset = State(wrappedValue: Point(x: 0, y: 0))
        Renders().render(ScrollView { Text("a") }.scrollOffset(offset.projectedValue).node)
        let image = try XCTUnwrap(offset.storage.walkedImage())
        typealias Lanes = JourneyLanes<Point>
        let y = HostStorage.bit(of: Lanes.range(of: .destination).lowerBound + 1)

        let beforeMove = image.pendingMask
        offset.projectedValue.journey.move(to: Point(x: 10, y: 0))
        XCTAssertEqual(image.pendingMask & ~beforeMove & y, 0, "the lane it does not change, left alone")

        offset.projectedValue.journey.move(to: Point(x: 10, y: 0))
        XCTAssertNotEqual(image.pendingMask & y, 0, "every lane laid again where none changes")
    }

    /// A LAW GIVEN TO A MOVE IS THAT MOVE'S ALONE: the value travels under it, its own law standing, and the next
    /// write that names no law - an assignment, or a move without one - travels under the value's own again.
    func testALawGivenToAMoveIsThatMovesAlone() throws {
        let offset = State(wrappedValue: Point(x: 0, y: 0), motion: .spring())
        Renders().render(ScrollView { Text("a") }.scrollOffset(offset.projectedValue).node)
        let image = try XCTUnwrap(offset.storage.walkedImage())
        let slow = Motion.eased(.milliseconds(2000))
        var now = 0.0
        let crossing = { () -> Motion? in
            now += 16
            Renderer.shared.board.cycle(now: now, reducesMotion: false)
            return self.law(crossing: image)
        }

        offset.projectedValue.journey.move(to: Point(x: 0, y: 5), slow)
        XCTAssertEqual(crossing(), slow, "the move travels under the law it was given")
        XCTAssertEqual(offset.projectedValue.journey.motion, .spring(), "the value's own law stands")

        offset.wrappedValue = Point(x: 0, y: 0)
        XCTAssertEqual(crossing(), .spring(), "an assignment travels under the value's own")

        offset.projectedValue.journey.move(to: Point(x: 0, y: 5), slow)
        offset.projectedValue.journey.move(to: Point(x: 0, y: 1))
        XCTAssertEqual(crossing(), .spring(), "and so does a move that names none")
    }

    /// THE LAW RIDES THE VALUE, not the view showing it. `.motion(_:)` on an
    /// element says how everything that element does travels; `@State(motion:)`
    /// says how THIS value travels wherever it is shown, and it survives on the
    /// image like every other lane.
    func testAValueCarriesItsOwnLaw() {
        let stated = State(wrappedValue: 0.0, motion: .spring())
        let plain = State(wrappedValue: 0.0)

        XCTAssertEqual(stated.projectedValue.journey.motion, .spring(), "the law is the value's own")
        XCTAssertEqual(plain.projectedValue.journey.motion, .inherited, "the element's, until said")

        stated.wrappedValue = 10
        XCTAssertEqual(stated.projectedValue.journey.motion, .spring(), "and sending it kept the law")

        XCTAssertNoThrow(try plain.projectedValue.journey.setMotion(.eased(.milliseconds(90), curve: .linear)))
        XCTAssertEqual(plain.projectedValue.journey.motion, .eased(.milliseconds(90), curve: .linear), "written later, it is the value's too")
    }

    /// A motion given to a move of a state nothing shows goes with the move, which made no movement: the value's
    /// own motion stands.
    func testAMotionGivenToAMoveOfAStateNothingShowsGoesWithIt() {
        let fade = State(wrappedValue: 1.0)

        let run = fade.projectedValue.journey.move(to: 0, .eased(.milliseconds(400), curve: .cubicIn))

        XCTAssertEqual(run.outcome, .notStarted(.noReceiver))
        XCTAssertEqual(fade.projectedValue.journey.motion, .inherited, "the value's own motion")
    }

    /// `.none` given to a move is the law that does not move, never "no law given": the value travels under it, not
    /// under its own.
    func testAMoveGivenNoMotionTravelsUnderNone() throws {
        let offset = State(wrappedValue: Point(x: 0, y: 0), motion: .spring())
        Renders().render(ScrollView { Text("a") }.scrollOffset(offset.projectedValue).node)
        let image = try XCTUnwrap(offset.storage.walkedImage())

        offset.projectedValue.journey.move(to: Point(x: 0, y: 5), .none)
        Renderer.shared.board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(law(crossing: image), Motion.none, "the law it was given, `.none`")
        XCTAssertEqual(offset.projectedValue.journey.motion, .spring(), "the value's own standing")
    }

    /// THE VALUE'S OWN LAW OVERRIDES THE ELEMENT'S, per property. `.inherited`
    /// is a REQUEST - the crossing answers it with whatever the element
    /// resolved - and anything else is an answer already given, which the
    /// crossing leaves alone. So a color driven from one value can travel the
    /// application's way while a coordinate driven from another, on the SAME
    /// element, travels its own.
    func testAValuesOwnLawSurvivesTheCrossingAndInheritedDoesNot() {
        let asked = HostStorage(StateImage.bytes(of: JourneyLanes(0.0).carried))
        let stated = HostStorage(
            StateImage.bytes(of: JourneyLanes(0.0, motion: .spring()).carried))

        for image in [asked, stated] {
            image.door = .property
            image.inherited = .eased(.milliseconds(200))
        }

        XCTAssertEqual(law(crossing: asked), .eased(.milliseconds(200)),
                       "`.inherited` is answered by the element's law")
        XCTAssertEqual(law(crossing: stated), .spring(),
                       "a law the value states is left alone")
    }

    /// A law said at the DECLARATION is on the image from birth - in the
    /// published bytes, so the very first crossing reads it - where one written
    /// afterwards is a write outside a cycle and waits to be latched. Leaving
    /// it out means `.inherited`, which the element answers.
    func testALawStatedAtTheDeclarationIsOnTheImageFromBirth() throws {
        let plain = State(wrappedValue: 0.0)
        let stated = State(wrappedValue: 0.0, motion: .spring())

        let images = try [plain, stated].map { try XCTUnwrap($0.projectedValue.journeyImage) }

        for image in images {
            image.door = .property
            image.inherited = .eased(.milliseconds(200))
        }

        XCTAssertEqual(law(crossing: images[0]), .eased(.milliseconds(200)),
                       "leaving it out means the element's")
        XCTAssertEqual(law(crossing: images[1]), .spring(),
                       "and a stated law is read before any cycle has run")
    }

    /// A HOST'S REPORT IS NO WORD ON A STATE AN ENGINE ANIMATES: the host is handed the engine's frame as its
    /// destination, lands there and says so every frame; the destination the author wrote, which the host never
    /// saw, stands, and so does what the engine says of the value.
    func testAHostsReportLeavesAStateAnEngineAnimatesAlone() throws {
        let handle = EngineHandle()
        let renders = Renders()
        renders.render(EngineDot(handle: handle).node)
        let board = Renderer.shared.board
        board.cycle(now: 0, reducesMotion: false)

        let offset = try XCTUnwrap(handle.offset)
        let number = try XCTUnwrap(offset.journeyImage?.number)
        offset.wrappedValue = 120
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)
        for frame in 1...150 {
            board.cycle(now: Double(frame) * 16, reducesMotion: false)
            let (binding, handed) = try XCTUnwrap(HostAnimatorReport.standing(number))
            let landed = HostJourney(
                value: handed.destination, destination: handed.destination, velocity: handed.velocity.map { _ in 0 },
                motion: handed.motion, completion: handed.completion, stopped: handed.stopped)
            XCTAssertFalse(
                HostBoundary.report(landed, updating: [.value, .destination, .velocity], through: binding),
                "the engine's journey is not the host's to report")
        }

        XCTAssertEqual(offset.wrappedValue, 120, "the author's destination stands")
        XCTAssertEqual(try XCTUnwrap(offset.journey.sample).value, 120, accuracy: 0.5, "the engine walked the value there")
    }

    /// WHO WALKS THE VALUE IS SETTLED AT THE DECLARATION: a state an engine
    /// animates is not given the host's law later, because the host was told
    /// at the first crossing and cannot be told again. No law says an engine:
    /// the declaration does.
    func testTheWalkerIsNotChangedAfterTheDeclaration() throws {
        let own = State(wrappedValue: 0.0, animatedBy: .engine)
        let renders = Renders()
        renders.render(Rectangle().translationY(own.projectedValue).node)
        let image = try XCTUnwrap(own.projectedValue.journeyImage)

        XCTAssertThrowsError(try own.projectedValue.journey.setMotion(.spring()), "refused, and said")
        XCTAssertNil(own.projectedValue.journey.motion, "an engine's state has no motion")
        XCTAssertEqual(law(publishedBy: image), .custom, "the engine still animates it")
    }

    /// The journey of a state the host carries AS THE VALUE - a feed, a plain number - has no sample: there are
    /// no lanes to walk. A move writes the value and says why nothing moved.
    func testTheJourneyOfAFedStateHasNoSample() {
        let room = State(wrappedValue: Rect(x: 0, y: 0, width: 0, height: 0))

        _ = room.number
        room.wrappedValue = Rect(x: 1, y: 2, width: 3, height: 4)

        let journey = room.projectedValue.journey

        XCTAssertNil(journey.sample)
        XCTAssertEqual(journey.move(to: Rect(x: 5, y: 6, width: 7, height: 8)).outcome, .notStarted(.unsupportedValue))
        XCTAssertEqual(room.wrappedValue, Rect(x: 5, y: 6, width: 7, height: 8), "the value is written all the same")
        XCTAssertNil(room.projectedValue.journeyImage, "and it stays carried as the value")
    }

    /// The law the image itself holds, before its crossing resolves it.
    private func law(publishedBy image: HostStorage) -> Motion? {
        guard let door = image.door, let at = StateLaw.within(door, lanes: image.published.count / 8) else { return nil }

        return StateLaw.motion(of: (0..<StateLaw.lanes).map { StateImage.lane(at + $0, of: image.published) })
    }

    /// The law lying in a crossing's bytes, read the way the host reads it.
    private func law(crossing image: HostStorage) -> Motion? {
        let bytes = image.crossing()

        guard let door = image.door,
              let at = StateLaw.within(door, lanes: bytes.count / 8)
        else { return nil }

        return StateLaw.motion(
            of: (0..<StateLaw.lanes).map { StateImage.lane(at + $0, of: bytes) })
    }
}

/// Where the dot's state is lent out to the test.
@MainActor
private final class EngineHandle {
    var offset: Binding<Double>?
}

/// A dot an engine of its own springs to where its state is sent, as the Gallery's Engine animation does.
private struct EngineDot: View {
    @State(animatedBy: .engine) private var offset = 0.0
    let handle: EngineHandle

    var body: some View {
        handle.offset = $offset
        return Rectangle()
            .translationX($offset)
            .engine(animating: $offset) { cycle, motion in
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
