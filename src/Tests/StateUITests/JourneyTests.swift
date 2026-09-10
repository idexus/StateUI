// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The journey every walked state is on, and what `$x.journey` offers.
//
// A state is DISCRETE - reading it answers the destination, writing it sends
// the value there - and its journey is a part of it: where the value is this
// frame, how fast, under what law, and the road to send it somewhere and wait.
// What these pin is that surface, the law's two homes (the declaration and the
// lanes), the landing rule for a state nothing wears, and `.custom`, which
// hands the walk to an engine on this side.
//
// Whose the value is, the number the host quotes it by and what a body that
// reads the journey pays are CarriedStateTests' and StateTests' business; this
// file is about the journey itself.

import XCTest
@testable import StateUI

final class JourneyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// The journey's lanes read as VALUES - where it is, where it is going, how
    /// fast - off a state that was declared as a plain number and had nothing
    /// said about a journey at all.
    func testEveryWalkedStateHasAJourney() {
        let rotation = State(wrappedValue: 2.0)
        let journey = rotation.projectedValue.journey

        XCTAssertEqual(journey.value, 2)
        XCTAssertEqual(journey.destination, 2, "a value standing still is going where it is")
        XCTAssertEqual(journey.velocity, 0)
        XCTAssertEqual(journey.motion, .inherited, "the element's, until said")
    }

    /// The state IS the destination: `rotation` and
    /// `$rotation.journey.destination` are one number, read and written.
    func testTheStateIsTheDestination() {
        let rotation = State(wrappedValue: 0.0)
        let journey = rotation.projectedValue.journey

        rotation.wrappedValue = 10
        XCTAssertEqual(journey.destination, 10, "a write to the state is a write to the destination")

        journey.destination = 4
        XCTAssertEqual(rotation.wrappedValue, 4, "and the other way round")
    }

    /// Writing where the value IS is a SNAP: whatever was carrying the property
    /// lets go, and the destination is left alone - which is what a value
    /// worked out per frame wants, and what makes it different from sending it.
    func testWritingTheValueOnTheJourneySnapsIt() {
        let rotation = State(wrappedValue: 0.0)
        let journey = rotation.projectedValue.journey

        rotation.wrappedValue = 10
        journey.value = 4

        XCTAssertEqual(journey.value, 4, "the screen moved")
        XCTAssertEqual(journey.destination, 10, "and the destination did not")
    }

    /// `snap(to:)` says all three at once - here, going nowhere, standing
    /// still - where writing the screen value alone leaves a destination
    /// behind that would send the host straight back.
    func testSnappingSaysHereGoingNowhereAndStandingStill() {
        let box = State(wrappedValue: 0.0)
        let journey = box.projectedValue.journey

        box.wrappedValue = 400
        journey.velocity = 9

        journey.snap(to: 240)

        XCTAssertEqual(journey.value, 240, "on the screen")
        XCTAssertEqual(journey.destination, 240, "and going nowhere else")
        XCTAssertEqual(journey.velocity, 0, "and not moving")
    }

    /// A STATE NOBODY WEARS LANDS WHERE IT IS WRITTEN. Until an element
    /// registers the state the host has no number for it and nothing walks it,
    /// so a write puts the value at the destination as well - and once an
    /// element has the number, a write moves the destination alone and the
    /// host walks the value there.
    func testAStateNobodyWearsLandsWhereItIsWritten() {
        let fade = State(wrappedValue: 1.0)
        let journey = fade.projectedValue.journey
        let renders = Renders()

        fade.wrappedValue = 0.2

        XCTAssertEqual(journey.value, 0.2, "nobody walks it, so it is there")
        XCTAssertEqual(journey.destination, 0.2)

        renders.render(BoxView().opacity(fade.projectedValue).body)

        fade.wrappedValue = 0.9

        XCTAssertEqual(journey.destination, 0.9, "the destination moved")
        XCTAssertEqual(journey.value, 0.2, "and the value waits for the host to walk it")
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

        plain.projectedValue.journey.motion = .eased(90, .linear)
        XCTAssertEqual(plain.projectedValue.journey.motion, .eased(90, .linear), "written later, it is the value's too")
    }

    /// THE VALUE'S OWN LAW OVERRIDES THE ELEMENT'S, per property. `.inherited`
    /// is a REQUEST - the crossing answers it with whatever the element
    /// resolved - and anything else is an answer already given, which the
    /// crossing leaves alone. So a colour driven from one value can travel the
    /// application's way while a coordinate driven from another, on the SAME
    /// element, travels its own.
    func testAValuesOwnLawSurvivesTheCrossingAndInheritedDoesNot() {
        let asked = HostStorage(StateImage.bytes(of: JourneyLanes(0.0).carried))
        let stated = HostStorage(
            StateImage.bytes(of: JourneyLanes(0.0, motion: .spring()).carried))

        for image in [asked, stated] {
            image.door = .property
            image.inherited = .eased(200, .cubicOut)
        }

        XCTAssertEqual(law(crossing: asked), .eased(200, .cubicOut),
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
            image.inherited = .eased(200, .cubicOut)
        }

        XCTAssertEqual(law(crossing: images[0]), .eased(200, .cubicOut),
                       "leaving it out means the element's")
        XCTAssertEqual(law(crossing: images[1]), .spring(),
                       "and a stated law is read before any cycle has run")
    }

    /// `.custom` HANDS THE WALK TO AN ENGINE ON THIS SIDE. A write moves the
    /// destination alone - whoever wears the state or not - and the value
    /// stays where the engine left it; the engine's own write to the value is
    /// what moves the screen. On the wire the host is handed `.none` and a
    /// destination that is wherever the engine wrote the value, so it wears
    /// every frame as it comes and walks nothing.
    func testACustomLawLeavesTheValueToTheEngine() throws {
        let ball = State(wrappedValue: 0.0, motion: .custom)
        let journey = ball.projectedValue.journey
        let renders = Renders()

        renders.render(BoxView().translationY(ball.projectedValue).body)

        ball.wrappedValue = 100

        XCTAssertEqual(journey.destination, 100)
        XCTAssertEqual(journey.value, 0, "the host walks nothing, and neither does a write")

        // The engine's frame.
        journey.value = 40
        journey.velocity = 8

        XCTAssertEqual(journey.value, 40)
        XCTAssertEqual(journey.destination, 100, "which the engine reads back")

        let image = try XCTUnwrap(ball.projectedValue.journeyImage)
        let board = Renderer.shared.board(of: image)

        board.cycle(now: 0, reducesMotion: false)

        let crossed = image.crossing()

        XCTAssertEqual(law(crossing: image), Motion.none, "the host is told not to walk")
        XCTAssertEqual(StateImage.lane(0, of: crossed), 40, "and where the engine put the value")
        XCTAssertEqual(StateImage.lane(1, of: crossed), 40, "is where it is told the value is going")
        XCTAssertEqual(journey.motion, .custom, "while the image itself goes on saying whose the walk is")
    }

    /// WHO WALKS THE VALUE IS SETTLED AT THE DECLARATION: `.custom` cannot be
    /// written onto a walking value, and a value declared `.custom` is not
    /// given the host's law later, because the host was told at the first
    /// crossing and cannot be told again.
    func testTheWalkerIsNotChangedAfterTheDeclaration() {
        let hosted = State(wrappedValue: 0.0)
        let own = State(wrappedValue: 0.0, motion: .custom)

        _ = hosted.projectedValue.journeyImage
        _ = own.projectedValue.journeyImage

        hosted.projectedValue.journey.motion = .custom
        XCTAssertEqual(hosted.projectedValue.journey.motion, .inherited, "refused, and said")

        own.projectedValue.journey.motion = .spring()
        XCTAssertEqual(own.projectedValue.journey.motion, .custom, "refused the other way too")
    }

    /// A `move` awaited on a `.custom` value writes the destination and answers
    /// at once: the walk is the engine's, and the engine is the only one that
    /// knows when it is done.
    func testAMoveUnderACustomLawAnswersAtOnce() async throws {
        let ball = State(wrappedValue: 0.0, motion: .custom)
        let binding = ball.projectedValue
        let renders = Renders()

        renders.render(BoxView().translationY(binding).body)

        let arrived = try await withThrowingTaskGroup(of: Bool?.self) { group in
            group.addTask { try await binding.journey.move(to: 50) }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                return nil
            }
            let first = try await group.next() ?? nil
            group.cancelAll()
            return first
        }

        XCTAssertEqual(arrived, true)
        XCTAssertEqual(ball.wrappedValue, 50, "the destination was written")
        XCTAssertEqual(binding.journey.value, 0, "and the value was left to the engine")
    }

    /// The journey of a state the host carries AS THE VALUE - a feed, a plain
    /// number - stands at that value and says nothing else: there are no lanes
    /// to read, and no journey to send anywhere.
    func testTheJourneyOfAFedStateStandsAtTheValue() {
        let room = State(wrappedValue: Rect(0, 0, 0, 0))

        _ = room.number
        room.wrappedValue = Rect(1, 2, 3, 4)

        let journey = room.projectedValue.journey

        XCTAssertEqual(journey.value, Rect(1, 2, 3, 4))
        XCTAssertEqual(journey.destination, Rect(1, 2, 3, 4))
        XCTAssertEqual(journey.velocity, Rect(0, 0, 0, 0))
        XCTAssertNil(room.projectedValue.journeyImage, "and it stays carried as the value")
    }

    /// A CONVERSION OF THE JOURNEY FOLLOWS THE WALK, where a conversion of the
    /// state shows the destination: the words are settled from where the value
    /// IS on every frame the host writes, and a destination write moves them
    /// not at all.
    func testAJourneyConverterFollowsTheWalk() {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()

        let walking = fade.projectedValue.journey.convert { "at \(Int($0.value * 100))" }
        let going = fade.projectedValue.convert { "going to \(Int($0 * 100))" }

        renders.render(BoxView().opacity(fade.projectedValue).body)

        moved(fade.number, to: [0.5, 1, 0, 0, 0, 0, 0, 0], mask: 0b1)

        XCTAssertEqual(walking.wrappedValue, "at 50", "the frame reached the words")
        XCTAssertEqual(going.wrappedValue, "going to 100", "and not the destination's")

        fade.wrappedValue = 0

        XCTAssertEqual(walking.wrappedValue, "at 50", "a destination written moves the walk's words not at all")
        XCTAssertEqual(going.wrappedValue, "going to 0", "and moves the state's at once")
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
