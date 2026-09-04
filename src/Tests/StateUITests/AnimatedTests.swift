// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The declaration whose plain name is where the value is GOING.
//
// What has to hold, and each of these is one test below: assigning it SENDS it
// and does not snap it; reading it answers the destination rather than the
// screen; the screen's value is reached through the binding and writing that
// one snaps; the binding is the same type a driven modifier has always taken,
// so nothing in Views/Driven.swift moves; and the box is adopted across a
// render the way every other declaration's is.

import XCTest
@testable import StateUI

final class AnimatedTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearStates()
    }

    /// THE WHOLE POINT OF THE DECLARATION. `rotation = 10` is a destination,
    /// which is what an assignment means everywhere else in this library: a
    /// value that changes is a setpoint and the host takes the control there.
    /// The value ON SCREEN has not moved yet, and must not have.
    func testAssigningAnAnimatedStateSendsItRatherThanSnappingIt() {
        let rotation = Animated(wrappedValue: 0.0)

        rotation.wrappedValue = 10

        let journey = rotation.projectedValue.wrappedValue

        XCTAssertEqual(journey.setPoint, 10, "the assignment said where it is going")
        XCTAssertEqual(journey.value, 0, "and where it IS has not moved")
    }

    /// Reading it answers the DESTINATION, not the screen - the state stands at
    /// the target the whole way, which is what lets a render in the middle of a
    /// travel say nothing and lets the travel go on.
    func testReadingAnAnimatedStateAnswersTheTarget() {
        let rotation = Animated(wrappedValue: 0.0)

        rotation.wrappedValue = 10

        XCTAssertEqual(rotation.wrappedValue, 10, "the plain name is the target")
        XCTAssertEqual(rotation.get(), 10, "and every road to it reads the same")
    }

    /// The screen's value is reached through the binding, and writing it SNAPS:
    /// whatever was carrying the property lets go, which is the deliberate
    /// escape from the sentence the plain name says.
    func testWritingTheValueOnTheBindingSnapsIt() {
        let rotation = Animated(wrappedValue: 0.0)

        rotation.projectedValue.value = 4

        XCTAssertEqual(rotation.projectedValue.value, 4, "the screen moved")
        XCTAssertEqual(rotation.wrappedValue, 0, "and the destination did not")
    }

    /// THE REASON Views/Driven.swift DOES NOT MOVE: `$rotation` is the same
    /// `Binding<AnimatedValue<T>>` a driven modifier has always taken, so an
    /// element driven from this declaration writes the registration it wrote
    /// before this declaration existed.
    func testAnAnimatedStateDrivesAPropertyTheWayABusDid() {
        let fade = Animated(wrappedValue: 1.0)
        let renders = Renders()

        let patch = renders.render(Label("x").opacity(fade.projectedValue).id("l").node)

        XCTAssertEqual(
            patch.driven?[.opacity],
            StateEntry(number: fade.number, mode: .inOut, kind: .property))
    }

    /// A state the host walks is one piece of state across renders, found by
    /// the property's own name - so the box a second render builds takes over
    /// the first one's image and the number stays the one the host was given.
    func testAnAnimatedStateIsAdoptedAcrossARender() {
        let first = Animated(wrappedValue: 1.0)
        let second = Animated(wrappedValue: 1.0)

        first.wrappedValue = 10
        second.adopt(from: first)

        XCTAssertEqual(second.number, first.number, "one state, one number")
        XCTAssertEqual(second.wrappedValue, 10, "and the value came with it")
    }

    /// THE LAW RIDES THE VALUE, not the view showing it. `.motion(_:)` on an
    /// element says how everything that element does travels; this says how
    /// THIS value travels wherever it is shown, and it survives on the image
    /// like every other lane.
    func testAValueCarriesItsOwnLaw() {
        let rotation = Animated(wrappedValue: 0.0)

        XCTAssertEqual(rotation.projectedValue.motion, .inherited, "the element's, until said")

        rotation.projectedValue.motion = .spring()
        rotation.wrappedValue = 10

        XCTAssertEqual(rotation.projectedValue.motion, .spring(), "the law is the value's own")
        XCTAssertEqual(rotation.projectedValue.setPoint, 10, "and sending it kept the law")
    }

    /// The four lanes read as VALUES rather than as bindings to parts, which is
    /// what a real member does and `@dynamicMemberLookup` does not - a lookup
    /// never fails, so without these `$rotation.value = 4` would quietly assign
    /// to the wrong kind of thing.
    func testTheJourneysLanesReadAsValues() {
        let rotation = Animated(wrappedValue: 2.0)

        let here: Double = rotation.projectedValue.value
        let going: Double = rotation.projectedValue.setPoint
        let speed: Double = rotation.projectedValue.velocity

        XCTAssertEqual(here, 2)
        XCTAssertEqual(going, 2, "a value standing still is going where it is")
        XCTAssertEqual(speed, 0)
    }

    /// THE VALUE'S OWN LAW OVERRIDES THE ELEMENT'S, per property. `.inherited`
    /// is a REQUEST - the crossing answers it with whatever the element
    /// resolved - and anything else is an answer already given, which the
    /// crossing leaves alone. So a colour driven from one value can travel the
    /// application's way while a coordinate driven from another, on the SAME
    /// element, travels its own.
    func testAValuesOwnLawSurvivesTheCrossingAndInheritedDoesNot() {
        let asked = HostStorage(StateImage.bytes(of: AnimatedValue(0.0).carried))
        let stated = HostStorage(
            StateImage.bytes(of: AnimatedValue(0.0, motion: .spring()).carried))

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
    func testALawStatedAtTheDeclarationIsOnTheImageFromBirth() {
        let plain = Animated(wrappedValue: 0.0)
        let stated = Animated(wrappedValue: 0.0, motion: .spring())

        for image in [plain.image, stated.image] {
            image.door = .property
            image.inherited = .eased(200, .cubicOut)
        }

        XCTAssertEqual(law(crossing: plain.image), .eased(200, .cubicOut),
                       "leaving it out means the element's")
        XCTAssertEqual(law(crossing: stated.image), .spring(),
                       "and a stated law is read before any cycle has run")
    }

    /// `snap(to:)` says all three at once - here, going nowhere, standing
    /// still - where writing the screen value alone leaves a set point behind
    /// that would send the host straight back.
    func testSnappingSaysHereGoingNowhereAndStandingStill() {
        let box = Animated(wrappedValue: 0.0)

        box.wrappedValue = 400
        box.projectedValue.velocity = 9

        box.projectedValue.snap(to: 240)

        XCTAssertEqual(box.projectedValue.value, 240, "on the screen")
        XCTAssertEqual(box.wrappedValue, 240, "and going nowhere else")
        XCTAssertEqual(box.projectedValue.velocity, 0, "and not moving")
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
