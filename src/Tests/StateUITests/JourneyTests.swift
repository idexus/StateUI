// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The value with a journey in it, and what a binding to one offers.
//
// An `AnimatedValue` is the one shape a `@Bus` carries that says more than
// where the value is: where it is GOING, how fast, and under what law. What
// these pin is the surface a binding to one puts on those four lanes - the
// part that is easy to lose in silence, because `Binding` is
// `@dynamicMemberLookup` and a lookup NEVER fails.
//
// Whose the value is, the number the host quotes it by and how a law crosses
// are BusTests' business; this file is about the journey itself.

import XCTest
@testable import StateUI

final class JourneyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearStates()
    }

    /// The four lanes read as VALUES rather than as bindings to parts, which is
    /// what a real member does and `@dynamicMemberLookup` does not - a lookup
    /// never fails, so without these `$rotation.value = 4` would quietly assign
    /// to the wrong kind of thing.
    func testTheJourneysLanesReadAsValues() {
        let rotation = Bus(wrappedValue: AnimatedValue(2.0))

        let here: Double = rotation.projectedValue.value
        let going: Double = rotation.projectedValue.setPoint
        let speed: Double = rotation.projectedValue.velocity

        XCTAssertEqual(here, 2)
        XCTAssertEqual(going, 2, "a value standing still is going where it is")
        XCTAssertEqual(speed, 0)
    }

    /// Writing where the value IS is a SNAP: whatever was carrying the property
    /// lets go, and the destination is left alone - which is what a value
    /// worked out per frame wants, and what makes it different from sending it.
    func testWritingTheValueOnTheBindingSnapsIt() {
        let rotation = Bus(wrappedValue: AnimatedValue(0.0))

        rotation.projectedValue.setPoint = 10
        rotation.projectedValue.value = 4

        XCTAssertEqual(rotation.projectedValue.value, 4, "the screen moved")
        XCTAssertEqual(rotation.projectedValue.setPoint, 10, "and the destination did not")
    }

    /// `snap(to:)` says all three at once - here, going nowhere, standing
    /// still - where writing the screen value alone leaves a set point behind
    /// that would send the host straight back.
    func testSnappingSaysHereGoingNowhereAndStandingStill() {
        let box = Bus(wrappedValue: AnimatedValue(0.0))

        box.projectedValue.setPoint = 400
        box.projectedValue.velocity = 9

        box.projectedValue.snap(to: 240)

        XCTAssertEqual(box.projectedValue.value, 240, "on the screen")
        XCTAssertEqual(box.projectedValue.setPoint, 240, "and going nowhere else")
        XCTAssertEqual(box.projectedValue.velocity, 0, "and not moving")
    }

    /// THE LAW RIDES THE VALUE, not the view showing it. `.motion(_:)` on an
    /// element says how everything that element does travels; this says how
    /// THIS value travels wherever it is shown, and it survives on the image
    /// like every other lane.
    func testAValueCarriesItsOwnLaw() {
        let rotation = Bus(wrappedValue: AnimatedValue(0.0))

        XCTAssertEqual(rotation.projectedValue.motion, .inherited, "the element's, until said")

        rotation.projectedValue.motion = .spring()
        rotation.projectedValue.setPoint = 10

        XCTAssertEqual(rotation.projectedValue.motion, .spring(), "the law is the value's own")
        XCTAssertEqual(rotation.projectedValue.setPoint, 10, "and sending it kept the law")
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

    /// A law said where the value is BUILT is on the image from birth - in the
    /// published bytes, so the very first crossing reads it - where one written
    /// afterwards is a write outside a cycle and waits to be latched. Leaving
    /// it out means `.inherited`, which the element answers.
    func testALawStatedAtTheValueIsOnTheImageFromBirth() {
        let plain = Bus(wrappedValue: AnimatedValue(0.0))
        let stated = Bus(wrappedValue: AnimatedValue(0.0, motion: .spring()))

        for image in [plain.image, stated.image] {
            image.door = .property
            image.inherited = .eased(200, .cubicOut)
        }

        XCTAssertEqual(law(crossing: plain.image), .eased(200, .cubicOut),
                       "leaving it out means the element's")
        XCTAssertEqual(law(crossing: stated.image), .spring(),
                       "and a stated law is read before any cycle has run")
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
