// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a REGISTRATION looks like on the wire, and the two guards that keep the
// driven surface and the flown surface in step.
//
// A registration is the whole of what a driven property ever says: nine
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
        // test read them first: a state's number is issued from a counter the
        // whole process shares. See Core/StateValue.swift.
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
    /// registration says the host also reads that property off a driven state, and
    /// neither is a complaint about the other. The state is there so the host
    /// side can be held to what a state LEAVING does to a driven
    /// property.
    func testADrivenPropertyBesideAStatedValueIsWrittenDown() throws {
        let fade = Animated(wrappedValue: 1.0)

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
        let number = Animated(wrappedValue: 0.5)
        let colour = Animated(wrappedValue: Color("#102030"))
        let inset = Animated(wrappedValue: Thickness(4))

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
        let caption = Bus(wrappedValue: "60%")

        try check(
            message(VStack { Label().text(caption.projectedValue); Button().text(caption.projectedValue) }.body),
            against: "state-text")
    }

    /// The two-way inputs, whose value the reader can move as well.
    func testADrivenInputIsWrittenDown() throws {
        let level = Animated(wrappedValue: 0.5)
        let steps = Animated(wrappedValue: 3.0)

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
        let run = Bus(wrappedValue: PlacedRun())
        let room = Bus(wrappedValue: Rect(0, 0, 0, 0))

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
    /// asking a state for its number is what issues one, and a Dictionary has no
    /// order at all - Swift salts its hashing per process, so numbering them as
    /// they happen to be stored would give one tree different numbers in two
    /// runs, and a fixture's bytes are a contract.
    ///
    /// Written the other way round from the order they come out in, so the
    /// sort is what the assertion is about.
    func testTwoDrivenPropertiesOnOneElementNumberInTheOrderTheirNamesDo() {
        let moved = Animated(wrappedValue: 0.0)
        let faded = Animated(wrappedValue: 1.0)
        let differ = Differ()

        _ = differ.reconcile(
            nil,
            with: message(Label("x").translationX(moved.projectedValue).opacity(faded.projectedValue).body))

        XCTAssertEqual(faded.number, 1, "opacity sorts before translationX")
        XCTAssertEqual(moved.number, 2)
    }

    // MARK: - The guards

    /// Every driven modifier names a real property of the same name, of a value
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
                "`\(overload.name)` is driven by \(overload.type), which nothing carries")
            XCTAssertTrue(
                values.contains(overload.name),
                "`\(overload.name)` is driven but no modifier of that name takes a value")
        }
    }

    /// THE TWO SURFACES STAY IN STEP: every property that can be flown from a
    /// `Binding` can be driven by a bus, and the driven form is
    /// the one a value moved by hand is meant to use.
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
        let driven = try names(in: "Views/Driven.swift", taking: "state")

        XCTAssertGreaterThan(armed.count, 20, "the scan read too few armed modifiers")
        XCTAssertEqual(
            armed.subtracting(driven), [],
            "these can be flown from a binding and cannot be driven by a bus")
    }

    /// A CONTROL'S PURPOSE-VALUE IS WRITABLE BOTH WAYS, AND THE TWO AGREE.
    ///
    /// `Slider($v)` and `Slider().value($v)` are one thing said twice - the
    /// initializer is the short way to say what gives a control its purpose,
    /// the modifier is how every other property is written, and neither is the
    /// real one. What this holds is that they describe the SAME NODE: the
    /// initializers delegate to the modifiers, so a change to one cannot leave
    /// the other behind.
    ///
    /// It is the pairing that matters rather than the exact bytes, so the
    /// comparison is the node's props and the events it handles - a handler's
    /// ID is issued per registration and differs by construction.
    func testEveryPurposeValueIsWritableBothWays() {
        func same(_ one: Node, _ other: Node, _ what: String) {
            XCTAssertEqual(
                one.props, other.props,
                "\(what): the two spellings describe different values")
            XCTAssertEqual(
                Set(one.events.keys), Set(other.events.keys),
                "\(what): the two spellings report different events")
        }

        let text = State(wrappedValue: "a")
        let number = State(wrappedValue: 0.5)
        let flag = State(wrappedValue: true)

        same(Entry(text.projectedValue).node,
             Entry().text(text.projectedValue).node, "Entry.text")
        same(Editor(text.projectedValue).node,
             Editor().text(text.projectedValue).node, "Editor.text")
        same(SearchBar(text.projectedValue).node,
             SearchBar().text(text.projectedValue).node, "SearchBar.text")
        same(Slider(number.projectedValue).node,
             Slider().value(number.projectedValue).node, "Slider.value")
        same(Stepper(number.projectedValue).node,
             Stepper().value(number.projectedValue).node, "Stepper.value")
        same(Switch(flag.projectedValue).node,
             Switch().isToggled(flag.projectedValue).node, "Switch.isToggled")
        same(CheckBox(flag.projectedValue).node,
             CheckBox().isChecked(flag.projectedValue).node, "CheckBox.isChecked")
    }

    /// AND SO IS A DRIVEN ONE: `Slider($level)` where `level` was declared
    /// driven says exactly what `Slider().value($level)` says.
    ///
    /// This is the whole of the model on one line - an author writes
    /// `Slider($x)` and the holder on the declaration decides whether the
    /// tree shows the value or the host carries it. Nothing at the call site
    /// says which.
    func testADrivenPurposeValueIsWritableBothWays() {
        Renderer.shared.clearStates()

        let level = Animated(wrappedValue: 0.5)
        let steps = Animated(wrappedValue: 3.0)

        func registers<Control: View>(
            _ one: Control, _ other: Control, _ what: String
        ) {
            let mine = one.node.driven
            let theirs = other.node.driven

            XCTAssertEqual(
                Set(mine.keys), Set(theirs.keys),
                "\(what): the two spellings drive different properties")

            for (property, registration) in mine {
                let twin = theirs[property]

                XCTAssertEqual(
                    registration.mode, twin?.mode,
                    "\(what).\(property.name): the two spellings cross differently")
                XCTAssertEqual(
                    registration.kind, twin?.kind,
                    "\(what).\(property.name): the two spellings use different doors")
            }

            XCTAssertFalse(mine.isEmpty, "\(what): nothing was driven at all")
        }

        registers(Slider(level.projectedValue),
                  Slider().value(level.projectedValue), "Slider")
        registers(Stepper(steps.projectedValue),
                  Stepper().value(steps.projectedValue), "Stepper")
    }
}
