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
// The mechanism is in Core/HostState.swift; the host's half - which runs the
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
    @State(describing: .none) var offset = 0.0
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

final class DrivenStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    // MARK: - The value

    /// Writing one asks for no render and names no change - which is the whole
    /// of what makes it affordable to move with a finger.
    func testWritingADrivenStateAsksForNoRender() {
        let value = State(wrappedValue: 0.0, describing: .none)

        value.wrappedValue = 40

        XCTAssertEqual(value.wrappedValue, 40)
        XCTAssertFalse(Renderer.shared.needsRender)
        XCTAssertTrue(Renderer.shared.pendingChanges.isEmpty)
    }

    /// And reading one records no dependency, so the view that read it is not
    /// rebuilt when it moves. The trade is the point: a view cannot SHOW one.
    func testReadingOneRecordsNothing() {
        let value = State(wrappedValue: 0.0, describing: .none)
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
        let value = State(wrappedValue: 0.0, describing: .none)
        let number = value.number!

        moved(number, to: 91.5)

        XCTAssertEqual(value.wrappedValue, 91.5)
    }

    /// A value is issued ONE number however often it is asked for it: the host
    /// quotes that number back, and a second one would be a second value.
    func testAStateNumberIsIssuedOnce() {
        let value = State(wrappedValue: 0.0, describing: .none)

        XCTAssertEqual(value.number!, value.number!)
        XCTAssertNotEqual(value.number!, State(wrappedValue: 0.0, describing: .none).number)
    }

    /// A view is a value REBUILT on every render, and the wrapper is rebuilt
    /// with it - so the storage has to be taken over, or the host would be
    /// moving a value nothing reads. One number and one value across both.
    func testADrivenStateRenderedTwiceCarriesOneNumber() {
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
    func testADrivenStateKeepsWhatTheHostWroteAcrossARender() {
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
        let fade = State(wrappedValue: AnimatedValue(1.0), describing: .none)
        let renders = Renders()

        let patch = renders.render(Plain().opacity(fade.projectedValue).id("plain").body)

        XCTAssertEqual(
            patch.driven?[.opacity],
            StateEntry(number: fade.number!, mode: .inOut, kind: .property))
    }

    /// A scroller told to report into a driven state says so as a number, and
    /// no handler at all - there is nothing to run on this side.
    func testAScrollerNamesTheStateItReportsInto() {
        let value = State(wrappedValue: 0.0, describing: .none)

        let node = ScrollView { Label("x") }
            .orientation(.horizontal)
            .scrollX(value.projectedValue)
            .body

        XCTAssertEqual(node.props[.scrollXChannel], .number(Double(value.number!)))
        XCTAssertNil(node.events[.scrollXChanged])
    }

    /// A view whose drag is written into values says both numbers.
    func testADraggedViewNamesTheValuesItIsWrittenInto() {
        let across = State(wrappedValue: 0.0, describing: .none)
        let down = State(wrappedValue: 0.0, describing: .none)

        let node = BoxView(Color("#000000")).panX(across.projectedValue).panY(down.projectedValue).body

        XCTAssertEqual(node.props[.panXChannel], .number(Double(across.number!)))
        XCTAssertEqual(node.props[.panYChannel], .number(Double(down.number!)))
    }

    // MARK: - The reader

    /// A `ScrollReader` lays an empty scroller over what it holds, as long as
    /// the room plus how far the run goes beyond it, reporting into the
    /// state.
    func testAScrollReaderReportsIntoItsState() {
        let across = State(wrappedValue: 0.0, describing: .none)
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

        XCTAssertEqual(found?.props[.scrollXChannel], .number(Double(across.number!)))
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
        let fade = State(wrappedValue: AnimatedValue(1.0), describing: .none)
        let renders = Renders()

        renders.render(Label("x").motion(.spring(response: 450, damping: 0.7))
            .opacity(fade.projectedValue).id("one").body)

        XCTAssertEqual(
            standing(fade.number!, as: AnimatedValue<Double>.self)?.motion,
            .spring(response: 450, damping: 0.7))
    }

    /// And the IMAGE goes on saying what the author wrote. `.inherited` is a
    /// request answered afresh on every crossing, which is what lets an
    /// element described later change the answer for a value already standing.
    func testTheValueItselfStillSaysInherited() {
        let fade = State(wrappedValue: AnimatedValue(1.0), describing: .none)
        let renders = Renders()

        renders.render(Label("x").motion(.spring()).opacity(fade.projectedValue).id("one").body)

        XCTAssertTrue(fade.wrappedValue.motion.isInherited)
    }

    /// An element given a NEW law answers for a value it was already driving:
    /// the resolution is the crossing's, not the write's.
    func testANewLawOnTheElementReachesAValueAlreadyStanding() {
        let fade = State(wrappedValue: AnimatedValue(1.0), describing: .none)
        let renders = Renders()

        renders.render(Label("x").motion(.eased(90, .linear))
            .opacity(fade.projectedValue).id("one").body)
        renders.render(Label("x").motion(.eased(700, .cubicIn))
            .opacity(fade.projectedValue).id("one").body)

        XCTAssertEqual(
            standing(fade.number!, as: AnimatedValue<Double>.self)?.motion,
            .eased(700, .cubicIn))
    }

    /// A rule naming COLOURS answers a driven colour, which the property alone
    /// cannot say - `backgroundColor` is in no group, and what puts it in one
    /// is the value it carries.
    func testARuleNamingColoursAnswersADrivenColour() {
        let tint = State(wrappedValue: AnimatedValue(Color("#102030")), describing: .none)
        let renders = Renders()

        renders.render(Label("x").motion(.none).motion(.eased(640, .cubicIn), .colour)
            .backgroundColor(tint.projectedValue).id("one").body)

        XCTAssertEqual(
            standing(tint.number!, as: AnimatedValue<Color>.self)?.motion,
            .eased(640, .cubicIn))
    }

    /// A value NO element drives says `.inherited` on the wire still, and the
    /// host answers it with the application's - there being no element to ask.
    func testAValueNobodyDrivesCrossesAsInherited() {
        let loose = State(wrappedValue: AnimatedValue(1.0), describing: .none)

        XCTAssertEqual(standing(loose.number!, as: AnimatedValue<Double>.self)?.motion, .inherited)
    }
}
