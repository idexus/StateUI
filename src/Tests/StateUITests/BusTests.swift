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

/// A view that reads a number, so a test can see that reading one records
/// nothing.
private struct Follower: ContentView {
    let value: Binding<Double>
    let builds: Builds

    var content: Element {
        builds.count += 1
        return label("at \(value.wrappedValue)")
    }
}

/// A view holding a driven state of its OWN, so a test can watch the wrapper a second
/// render builds take over the storage the first one made.
private struct Holder: ContentView {
    @Bus var offset = 0.0
    let seen: Seen

    var content: Element {
        seen.numbers.append($offset.number!)
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

final class BusTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    // MARK: - The value

    /// Writing one asks for no render and names no change - which is the whole
    /// of what makes it affordable to move with a finger.
    func testWritingABusAsksForNoRender() {
        let value = Bus(wrappedValue: 0.0)

        value.wrappedValue = 40

        XCTAssertEqual(value.wrappedValue, 40)
        XCTAssertFalse(Renderer.shared.needsRender)
        XCTAssertTrue(Renderer.shared.pendingChanges.isEmpty)
    }

    /// And reading one records no dependency, so the view that read it is not
    /// rebuilt when it moves. The trade is the point: a body may read one and
    /// print it, and the value moving is no reason to print it again - so what
    /// is on screen is whatever the last description for some other reason
    /// happened to say.
    func testReadingOneRecordsNothing() {
        let value = Bus(wrappedValue: 0.0)
        let builds = Builds()
        let renders = Renders()

        renders.render(stack([Follower(value: value.projectedValue, builds: builds).body], id: "root"))
        XCTAssertEqual(builds.count, 1)

        value.wrappedValue = 12
        renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(builds.count, 1)
    }

    /// The host says where it stands by the number it was issued, and the
    /// value is then what anything reading it sees - a handler asking where
    /// the run is, and the arithmetic itself.
    func testTheHostMovesItByItsNumber() {
        let value = Bus(wrappedValue: 0.0)
        let number = value.number

        moved(number, to: 91.5)

        XCTAssertEqual(value.wrappedValue, 91.5)
    }

    /// A value is issued ONE number however often it is asked for it: the host
    /// quotes that number back, and a second one would be a second value.
    func testABusNumberIsIssuedOnce() {
        let value = Bus(wrappedValue: 0.0)

        XCTAssertEqual(value.number, value.number)
        XCTAssertNotEqual(value.number, Bus(wrappedValue: 0.0).number)
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

    // MARK: - What a message says about it

    /// A DRIVEN STATE WRITTEN ON A COMPOSED VIEW IS ABOUT THAT VIEW, and reaches
    /// the element its body ends at.
    ///
    /// A composed view has no node of its own, so everything written on it is
    /// kept on a placeholder and carried onto what the body built. A
    /// registration left behind there would name a control nothing holds: the
    /// modifier would compile, the property would never be written, and
    /// nothing anywhere would say so.
    func testADrivenPropertyOnAComposedViewReachesItsElement() {
        let fade = Animated(wrappedValue: 1.0)
        let renders = Renders()

        let patch = renders.render(Plain().opacity(fade.projectedValue).id("plain").body)

        XCTAssertEqual(
            patch.driven?[.opacity],
            StateEntry(number: fade.number, mode: .inOut, kind: .property))
    }

    /// A scroller told to report into a driven state says so as a number, and
    /// no handler at all - there is nothing to run on this side.
    func testAScrollerNamesTheStateItReportsInto() {
        let value = Bus(wrappedValue: 0.0)

        let node = ScrollView { Label("x") }
            .orientation(.horizontal)
            .scrollX(value.projectedValue)
            .body

        XCTAssertEqual(node.props[.scrollXChannel], .number(Double(value.number)))
        XCTAssertNil(node.events[.scrollXChanged])
    }

    /// A view whose drag is written into values says both numbers.
    func testADraggedViewNamesTheValuesItIsWrittenInto() {
        let across = Bus(wrappedValue: 0.0)
        let down = Bus(wrappedValue: 0.0)

        let node = BoxView(Color("#000000")).panX(across.projectedValue).panY(down.projectedValue).body

        XCTAssertEqual(node.props[.panXChannel], .number(Double(across.number)))
        XCTAssertEqual(node.props[.panYChannel], .number(Double(down.number)))
    }

    // MARK: - The reader

    /// A `ScrollReader` lays an empty scroller over what it holds, as long as
    /// the room plus how far the run goes beyond it, reporting into the
    /// state.
    func testAScrollReaderReportsIntoItsState() {
        let across = Bus(wrappedValue: 0.0)
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
        let fade = Animated(wrappedValue: 1.0)
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
        let fade = Animated(wrappedValue: 1.0)
        let renders = Renders()

        renders.render(Label("x").motion(.spring()).opacity(fade.projectedValue).id("one").body)

        XCTAssertTrue(fade.projectedValue.motion.isInherited)
    }

    /// An element given a NEW law answers for a value it was already driving:
    /// the resolution is the crossing's, not the write's.
    func testANewLawOnTheElementReachesAValueAlreadyStanding() {
        let fade = Animated(wrappedValue: 1.0)
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
        let tint = Animated(wrappedValue: Color("#102030"))
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
        let loose = Animated(wrappedValue: 1.0)

        XCTAssertEqual(standing(loose.number, as: AnimatedValue<Double>.self)?.motion, .inherited)
    }

    /// An `AnimatedValue` the TREE describes has nothing to carry a journey,
    /// and says so at the call rather than answering that it arrived.
    ///
    /// A silent TRUE is the one answer it may not give - an author reads it as
    /// "it moved" - so this asserts the throw AND that nothing was written.
    ///
    /// Deprecated so that the declaration this test has to write - the very one
    /// `Core/Bus.swift` warns about - does not warn here.
    @available(*, deprecated)
    func testAnAnimatedValueTheTreeDescribesRefusesToFly() async throws {
        let fade = State(AnimatedValue(1.0))

        do {
            _ = try await fade.projectedValue.animateTo(0.1)
            XCTFail("a described AnimatedValue answered that it had arrived")
        } catch let error as StateUIError {
            XCTAssertTrue(
                error.message.contains("@Animated"),
                "the message names the fix: \(error.message)")
        }

        XCTAssertEqual(fade.get().value, 1.0, "and nothing was written")
    }

    /// A PART of a bus is not itself driven: the image is the whole value, and
    /// no message can say that a property rides one lane of it.
    ///
    /// The part still reads and writes - through the whole, as any derived
    /// binding does - so what this pins is which ROAD it takes, not whether it
    /// works.
    func testAPartOfABusIsNotDriven() {
        let room = Bus(wrappedValue: Rect(0, 0, 0, 0))

        XCTAssertNotNil(room.projectedValue.driving, "the whole value is driven")
        XCTAssertNil(
            room.projectedValue.width.driving,
            "one lane of it is not something the host can be aimed at")

        room.projectedValue.width.wrappedValue = 90

        XCTAssertEqual(room.wrappedValue.width, 90, "and the part still writes")
    }

    /// `update(_:)` on a bus MOVES the value, which is the whole of what a
    /// member on this declaration has to do.
    ///
    /// A bus keeps one image and nothing else, so there is no second storage
    /// for a read-change-write to land in: what this writes is what the next
    /// read answers with.
    func testUpdatingABusMovesTheValue() {
        let offset = Bus(wrappedValue: 12.0)

        offset.update { $0 + 30 }

        XCTAssertEqual(offset.wrappedValue, 42, "the write reached the image")
        XCTAssertEqual(offset.get(), 42, "and every road to it reads the same")
    }

}
