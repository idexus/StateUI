// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a REGISTRATION looks like on the wire, and the two guards that keep the
// number surface and the flown surface in step.
//
// A registration is the whole of what a number-carried property ever says: nine
// bytes, once, and then the value moves on the image where no message can see
// it. So these fixtures are the contract for the one field that decides
// whether the host reads a property off its own frames or off the tree.

import StateUIWireProbe
import XCTest
@testable import StateUI

final class DrivenWireTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()

        // The numbering starts over, so these bytes are the same whichever
        // test read them first: a number number is issued from a counter the
        // whole process shares. See Core/HostState.swift.
        Renderer.shared.clearStates()
    }

    /// Wraps a view the way a message is rooted - the application, a window and
    /// a page - so the fixture is a whole message rather than a fragment.
    private func message(_ content: Node) -> Node {
        Node(type: "Application", children: [
            Node(type: "Window", children: [
                Node(type: "ContentPage", children: [content]),
            ]),
        ])
    }

    private func check(_ tree: Node, against name: String) throws {
        let differ = Differ()
        let dictionary = WireDictionary()
        let names = WireNames()
        let result = differ.reconcile(nil, with: tree)
        let bytes = Wire.encode(result.patch, generation: 1, dictionary: dictionary)

        try Fixtures.check(bytes, sidecar: WireProbe.dumpMessage(bytes, names: names), against: name)
    }

    // MARK: - The fixtures

    /// A STATED VALUE, A VISUAL STATE AND A DRIVEN STATE ON ONE PROPERTY, which is the
    /// pair the whole design turns on: the value crosses as a value, the
    /// registration says the host also reads that property off a number, and
    /// neither is a complaint about the other. The state is there so the host
    /// side can be held to what a state LEAVING does to a number-driven
    /// property.
    func testADrivenPropertyBesideAStatedValueIsWrittenDown() throws {
        let fade = State(wrappedValue: AnimatedValue(1.0), describing: .none)

        try check(
            message(
                Border { Label("dimmed") }
                    .opacity(0.5)
                    .opacity(fade.projectedValue)
                    .visualState(.disabled) { $0.opacity(0.1) }
                    .body),
            against: "state-sink")
    }

    /// Every one of the thirty twins, on one element each of the tiers they
    /// live on - so a modifier that compiles and writes the wrong token is a
    /// changed sidecar rather than a surprise on a device.
    func testEveryDrivenModifierIsWrittenDown() throws {
        let number = State(wrappedValue: AnimatedValue(0.5), describing: .none)
        let colour = State(wrappedValue: AnimatedValue(Color("#102030")), describing: .none)
        let inset = State(wrappedValue: AnimatedValue(Thickness(4)), describing: .none)

        let border = Border {
            Label("words")
                .fontSize(number.projectedValue)
                .textColor(colour.projectedValue)
                .characterSpacing(number.projectedValue)
        }
        .opacity(number.projectedValue)
        .backgroundColor(colour.projectedValue)
        .widthRequest(number.projectedValue)
        .heightRequest(number.projectedValue)
        .minimumWidthRequest(number.projectedValue)
        .minimumHeightRequest(number.projectedValue)
        .maximumWidthRequest(number.projectedValue)
        .maximumHeightRequest(number.projectedValue)
        .rotation(number.projectedValue)
        .rotationX(number.projectedValue)
        .rotationY(number.projectedValue)
        .scale(number.projectedValue)
        .scaleX(number.projectedValue)
        .scaleY(number.projectedValue)
        .translationX(number.projectedValue)
        .translationY(number.projectedValue)
        .anchorX(number.projectedValue)
        .anchorY(number.projectedValue)
        .margin(inset.projectedValue)
        .padding(inset.projectedValue)

        let shape = Rectangle()
            .strokeThickness(number.projectedValue)
            .strokeDashOffset(number.projectedValue)
            .strokeMiterLimit(number.projectedValue)

        // A Button for the outline the mixin is about, and an Entry for the
        // placeholder - neither of them a Border's.
        let button = Button("press")
            .borderColor(colour.projectedValue)
            .borderWidth(number.projectedValue)

        let entry = Entry("").placeholderColor(colour.projectedValue)

        // And the one modifier that is a control's own rather than a tier's.
        let box = BoxView().color(colour.projectedValue)

        try check(
            message(VStack { border; shape; button; entry; box }.spacing(number.projectedValue).body),
            against: "state-modifiers")
    }

    /// Text, which has no lanes and no journey: it is written when the bytes
    /// change and never walked to.
    func testDrivenTextIsWrittenDown() throws {
        let caption = State(wrappedValue: "60%", describing: .none)

        try check(
            message(VStack { Label().text(caption.projectedValue); Button().text(caption.projectedValue) }.body),
            against: "state-text")
    }

    /// The two-way inputs, whose value the reader can move as well.
    func testADrivenInputIsWrittenDown() throws {
        let level = State(wrappedValue: AnimatedValue(0.5), describing: .none)
        let steps = State(wrappedValue: AnimatedValue(3.0), describing: .none)

        try check(
            message(VStack {
                Slider().value(level.projectedValue)
                Stepper().value(steps.projectedValue)
            }.body),
            against: "state-input")
    }

    /// A LAYOUT PLACED BY DRIVEN STATE, which says where its views go and nothing
    /// else: one registration on the layout, and not one of the twelve
    /// properties of a placement on any child of it.
    ///
    /// The wrapper around each face is the library's own and is always there,
    /// shaded or not - which is what keeps the host's writes off the author's
    /// view. A shaded run wraps two, the shade second.
    func testADrivenPlacedLayoutIsWrittenDown() throws {
        let run = State(wrappedValue: PlacedRun(), describing: .none)
        let room = State(wrappedValue: Rect(0, 0, 0, 0), describing: .none)

        try check(
            message(
                PlacedLayout(["a", "b"], id: \.self) { Label($0) }
                    .shade(BoxView(.black))
                    .placement(run.projectedValue)
                    .frame(room.projectedValue)
                    .body),
            against: "state-placed")
    }

    /// THE NUMBERS ARE THE WALK'S, and within one element the property NAMES':
    /// asking a number for its number is what issues one, and a Dictionary has no
    /// order at all - Swift salts its hashing per process, so numbering them as
    /// they happen to be stored would give one tree different numbers in two
    /// runs, and a fixture's bytes are a contract.
    ///
    /// Written the other way round from the order they come out in, so the
    /// sort is what the assertion is about.
    func testTwoDrivenPropertiesOnOneElementNumberInTheOrderTheirNamesDo() {
        let moved = State(wrappedValue: AnimatedValue(0.0), describing: .none)
        let faded = State(wrappedValue: AnimatedValue(1.0), describing: .none)
        let differ = Differ()

        _ = differ.reconcile(
            nil,
            with: message(Label("x").translationX(moved.projectedValue).opacity(faded.projectedValue).body))

        XCTAssertEqual(faded.number!, 1, "opacity sorts before translationX")
        XCTAssertEqual(moved.number!, 2)
    }

    // MARK: - The guards

    /// Every number modifier names a real property of the same name, of a value
    /// the host can carry.
    ///
    /// A driven overload for a property nothing declares, or for a value
    /// nothing interpolates, would compile and then do nothing at all - which
    /// is the one failure this library refuses to ship.
    func testEveryDrivenModifierNamesACarriedPropertyOfTheSameName() throws {
        let sources = try Fixtures.allSources()
        let states = try XCTUnwrap(sources.first { $0.path.hasSuffix("Views/Driven.swift") })

        var overloads: [(name: String, type: String)] = []

        for line in states.text.split(separator: "\n") {
            let written = String(line)

            guard let name = written.occurrences(between: "public func ", and: "(").first,
                  let type = written.occurrences(between: "AnimatedValue<", and: ">").first
            else { continue }

            overloads.append((name, type))
        }

        XCTAssertGreaterThan(
            overloads.count, 20, "the scan found too few overloads to be reading the right thing")

        // What the host has a blend for, and the whole of it - a number, a
        // colour and a thickness.
        let carried: Set<String> = ["Double", "Color", "Thickness"]

        // Line by line, deliberately: a scan over a whole file would read from
        // one declaration's "public func " to a LATER one's "(_ value:" and
        // come back with everything in between.
        var values: Set<String> = []

        for source in sources where !source.path.hasSuffix("Views/Driven.swift") {
            for line in source.text.split(separator: "\n") {
                values.formUnion(
                    String(line).occurrences(between: "public func ", and: "(_ value:"))
            }
        }

        for overload in overloads {
            XCTAssertTrue(
                carried.contains(overload.type),
                "`\(overload.name)` takes a number of \(overload.type), which nothing carries")
            XCTAssertTrue(
                values.contains(overload.name),
                "`\(overload.name)` takes a number but no modifier of that name takes a value")
        }
    }

    /// THE TWO SURFACES STAY IN STEP: every property that can be flown from a
    /// `Binding` can be driven to state the host moves, and the number form is the one a value
    /// moved by hand is meant to use.
    ///
    /// Read from the two files rather than written out here, so a modifier
    /// added to one and forgotten in the other fails by name.
    func testEveryArmedModifierHasADrivenTwin() throws {
        let sources = try Fixtures.allSources()

        func names(in file: String, taking argument: String) throws -> Set<String> {
            let source = try XCTUnwrap(sources.first { $0.path.hasSuffix(file) })
            var found: Set<String> = []

            for line in source.text.split(separator: "\n") {
                found.formUnion(
                    String(line).occurrences(between: "public func ", and: "(_ \(argument):"))
            }

            return found
        }

        let armed = try names(in: "Views/Armed.swift", taking: "binding")
        let driven = try names(in: "Views/Driven.swift", taking: "number")

        XCTAssertGreaterThan(armed.count, 20, "the scan read too few armed modifiers")
        XCTAssertEqual(
            armed.subtracting(driven), [],
            "these can be flown from a binding and cannot be driven to a number")
    }
}
