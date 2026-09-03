// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a REGISTRATION looks like on the wire, and the two guards that keep the
// bus surface and the flown surface in step.
//
// A registration is the whole of what a bus-carried property ever says: nine
// bytes, once, and then the value moves on the image where no message can see
// it. So these fixtures are the contract for the one field that decides
// whether the host reads a property off its own frames or off the tree.

import StateUIWireProbe
import XCTest
@testable import StateUI

final class BusWireTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()

        // The numbering starts over, so these bytes are the same whichever
        // test read them first: a bus number is issued from a counter the
        // whole process shares. See Core/Bus.swift.
        Renderer.shared.clearBuses()
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

    /// A STATED VALUE AND A BUS ON ONE PROPERTY, which is the pair the whole
    /// design turns on: the value crosses as a value, the registration says
    /// the host also reads that property off a bus, and neither is a complaint
    /// about the other.
    func testABusBesideAStatedValueIsWrittenDown() throws {
        let fade = Bus(wrappedValue: AnimatedValue(1.0))

        try check(
            message(Border { Label("dimmed") }.opacity(0.5).opacity(fade).body),
            against: "bus-sink")
    }

    /// Every one of the thirty twins, on one element each of the tiers they
    /// live on - so a modifier that compiles and writes the wrong token is a
    /// changed sidecar rather than a surprise on a device.
    func testEveryBusModifierIsWrittenDown() throws {
        let number = Bus(wrappedValue: AnimatedValue(0.5))
        let colour = Bus(wrappedValue: AnimatedValue(Color("#102030")))
        let inset = Bus(wrappedValue: AnimatedValue(Thickness(4)))

        let border = Border {
            Label("words")
                .fontSize(number)
                .textColor(colour)
                .characterSpacing(number)
        }
        .opacity(number)
        .backgroundColor(colour)
        .widthRequest(number)
        .heightRequest(number)
        .minimumWidthRequest(number)
        .minimumHeightRequest(number)
        .maximumWidthRequest(number)
        .maximumHeightRequest(number)
        .rotation(number)
        .rotationX(number)
        .rotationY(number)
        .scale(number)
        .scaleX(number)
        .scaleY(number)
        .translationX(number)
        .translationY(number)
        .anchorX(number)
        .anchorY(number)
        .margin(inset)
        .padding(inset)

        let shape = Rectangle()
            .strokeThickness(number)
            .strokeDashOffset(number)
            .strokeMiterLimit(number)

        // A Button for the outline the mixin is about, and an Entry for the
        // placeholder - neither of them a Border's.
        let button = Button("press")
            .borderColor(colour)
            .borderWidth(number)

        let entry = Entry("").placeholderColor(colour)

        try check(
            message(VStack { border; shape; button; entry }.spacing(number).body),
            against: "bus-modifiers")
    }

    /// Text, which has no lanes and no journey: it is written when the bytes
    /// change and never walked to.
    func testATextBusIsWrittenDown() throws {
        let caption = Bus(wrappedValue: "60%")

        try check(
            message(VStack { Label().text(caption); Button().text(caption) }.body),
            against: "bus-text")
    }

    /// The two-way inputs, whose value the reader can move as well.
    func testAnInputBusIsWrittenDown() throws {
        let level = Bus(wrappedValue: AnimatedValue(0.5))
        let steps = Bus(wrappedValue: AnimatedValue(3.0))

        try check(
            message(VStack {
                Slider().value(level)
                Stepper().value(steps, mode: .out)
            }.body),
            against: "bus-input")
    }

    /// THE NUMBERS ARE THE WALK'S, and within one element the property NAMES':
    /// asking a bus for its number is what issues one, and a Dictionary has no
    /// order at all - Swift salts its hashing per process, so numbering them as
    /// they happen to be stored would give one tree different numbers in two
    /// runs, and a fixture's bytes are a contract.
    ///
    /// Written the other way round from the order they come out in, so the
    /// sort is what the assertion is about.
    func testTwoBusesOnOneElementNumberInTheOrderTheirNamesDo() {
        let moved = Bus(wrappedValue: AnimatedValue(0.0))
        let faded = Bus(wrappedValue: AnimatedValue(1.0))
        let differ = Differ()

        _ = differ.reconcile(
            nil,
            with: message(Label("x").translationX(moved).opacity(faded).body))

        XCTAssertEqual(faded.bus, 1, "opacity sorts before translationX")
        XCTAssertEqual(moved.bus, 2)
    }

    // MARK: - The guards

    /// Every bus modifier names a real property of the same name, of a value
    /// the host can carry.
    ///
    /// A `Bus` overload for a property nothing declares, or for a value
    /// nothing interpolates, would compile and then do nothing at all - which
    /// is the one failure this library refuses to ship.
    func testEveryBusModifierNamesACarriedPropertyOfTheSameName() throws {
        let sources = try Fixtures.allSources()
        let buses = try XCTUnwrap(sources.first { $0.path.hasSuffix("Views/Buses.swift") })

        var overloads: [(name: String, type: String)] = []

        for line in buses.text.split(separator: "\n") {
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

        for source in sources where !source.path.hasSuffix("Views/Buses.swift") {
            for line in source.text.split(separator: "\n") {
                values.formUnion(
                    String(line).occurrences(between: "public func ", and: "(_ value:"))
            }
        }

        for overload in overloads {
            XCTAssertTrue(
                carried.contains(overload.type),
                "`\(overload.name)` takes a bus of \(overload.type), which nothing carries")
            XCTAssertTrue(
                values.contains(overload.name),
                "`\(overload.name)` takes a bus but no modifier of that name takes a value")
        }
    }

    /// THE TWO SURFACES STAY IN STEP: every property that can be flown from a
    /// `Binding` can be tied to a `Bus`, and the bus form is the one a value
    /// moved by hand is meant to use.
    ///
    /// Read from the two files rather than written out here, so a modifier
    /// added to one and forgotten in the other fails by name.
    func testEveryArmedModifierHasABusTwin() throws {
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
        let tied = try names(in: "Views/Buses.swift", taking: "bus")

        XCTAssertGreaterThan(armed.count, 20, "the scan read too few armed modifiers")
        XCTAssertEqual(
            armed.subtracting(tied), [],
            "these can be flown from a binding and cannot be tied to a bus")
    }
}
