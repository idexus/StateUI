// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a REGISTRATION looks like in a patch, and the two guards that keep the
// driven surface and the flown surface in step.
//
// A registration is the whole of what a driven property ever says: once, and
// then the value moves on the image where no patch can see it. So these
// assertions are the contract for the one field that decides whether the host
// reads a property off its own frames or off the tree.

import XCTest
@_spi(Host) @testable import StateUI

final class DrivenPatchTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()

        // The numbering starts over, so these patches are the same whichever
        // test read them first: a state's number is issued from a counter the
        // whole process shares. See Renderer+Cycle.swift.
        Renderer.shared.clearStates()
    }

    /// Wraps a view the way a render is rooted - the application, its scene,
    /// the scene's main window and a page - so the patch is a whole render
    /// rather than a fragment.
    private func rooted(_ content: Node) -> Node {
        var main = Node(type: "Window", children: [
            Node(type: "Page", children: [content]),
        ])
        main.id = SceneElement.mainKey

        var scene = Node(type: "Scene", children: [main])
        scene.id = "1"

        return Node(type: "Application", children: [scene])
    }

    /// The page of a first render of `content`: what stands under it is the
    /// content, `.auto(3)` first.
    private func page(_ content: Node) throws -> HostPatch {
        try XCTUnwrap(Differ().reconcile(nil, with: rooted(content)).patch
            .at(.manual("1"), .manual(SceneElement.mainKey), .auto(2)))
    }

    /// The registrations of the element at `path` below `page`.
    private func ties(_ page: HostPatch, _ path: ElementId...) -> [Prop: HostStateBinding] {
        page.at(path)?.driven?.bindings ?? [:]
    }

    /// Each of `properties` tied to one state, one way, on one channel.
    private func tied(
        _ properties: [Prop], to state: Int32, _ mode: HostStateMode, _ kind: HostStateKind
    ) -> [Prop: HostStateBinding] {
        Dictionary(uniqueKeysWithValues: properties.map {
            ($0, HostStateBinding(state: state, mode: mode, kind: kind))
        })
    }

    // MARK: - The registrations

    /// A STATED VALUE, A VISUAL STATE AND A DRIVEN STATE ON ONE PROPERTY, which is the
    /// pair the whole design turns on: the value crosses as a value, the
    /// registration says the host also reads that property off a driven state, and
    /// neither is a complaint about the other. The state is there so the host
    /// side can be held to what a state LEAVING does to a driven
    /// property.
    func testADrivenPropertyBesideAStatedValueCrossesAsBoth() throws {
        let fade = State(wrappedValue: 1.0)

        let page = try page(
            ZStack { Label("dimmed") }
                .opacity(0.5)
                .opacity(fade.projectedValue)
                .visualState(.disabled) { $0.opacity(0.1) }
                .body)
        let border = try XCTUnwrap(page.at(.auto(3)))

        XCTAssertEqual(border.props["opacity"], .number(0.5), "the stated value crosses as a value")
        XCTAssertEqual(ties(page, .auto(3)), tied(["opacity"], to: 1, .inOut, .property))

        let disabled = border.children.first { $0.type == .visualState && $0.props["name"] == .name("Disabled") }
        XCTAssertEqual(disabled?.children.first?.props, ["opacity": .number(0.1)], "and the state its own")
    }

    /// THE FIVE SHAPES A BINDING TAKES ON A PROPERTY, as a host is handed them: a journey
    /// from a plain number (`fontSize($size)`), a plain flag the host sets
    /// (`isVisible($shown)`), words (`placeholder($hint)`), a plain choice the
    /// host sets and reports (`selectedIndex($size)`, `isOn($on)`), and a
    /// MEMBER (`horizontalAlignment($side)`), which crosses as its number and is
    /// resolved by the host into the platform's own member. A host is held to
    /// landing each of them.
    func testEveryShapeOfABoundPropertyRegistersItsChannel() throws {
        let size = State(wrappedValue: 14.0)
        let shown = State(wrappedValue: true)
        let hint = State(wrappedValue: "Type here")
        let choice = State(wrappedValue: 1)
        let on = State(wrappedValue: false)
        let side = State(wrappedValue: Alignment.center)

        let page = try page(
            VStack {
                Label("bound")
                    .fontSize(size.projectedValue)
                    .isVisible(shown.projectedValue)
                    .horizontalAlignment(side.projectedValue)
                TextField()
                    .placeholder(hint.projectedValue)
                Picker(["S", "M", "L"])
                    .selectedIndex(choice.projectedValue)
                Switch(on.projectedValue)
            }
            .body)

        // Numbered in the walk, and within one element in the names' order.
        XCTAssertEqual(
            ties(page, .auto(3), .auto(4)),
            tied(["fontSize"], to: 1, .inOut, .property)
                .merging(tied(["horizontalAlignment"], to: 2, .out, .plain)) { $1 }
                .merging(tied(["isVisible"], to: 3, .out, .plain)) { $1 })
        XCTAssertEqual(ties(page, .auto(3), .auto(5)), tied(["placeholder"], to: 4, .out, .text))
        XCTAssertEqual(ties(page, .auto(3), .auto(6)), tied(["selectedIndex"], to: 5, .inOut, .plain))
        XCTAssertEqual(ties(page, .auto(3), .auto(7)), tied(["isOn"], to: 6, .inOut, .plain))
    }

    /// Every one of the thirty twins, on one element each of the tiers they
    /// live on - so a modifier that compiles and writes the wrong token fails
    /// here rather than surprising a device.
    func testEveryDrivenModifierRegistersItsProperty() throws {
        let number = State(wrappedValue: 0.5)
        let colour = State(wrappedValue: Color("#102030"))
        let inset = State(wrappedValue: Insets(4))

        let border = ZStack {
            Label("words")
                .fontSize(number.projectedValue)
                .textColor(colour.projectedValue)
                .characterSpacing(number.projectedValue)
        }
        .opacity(number.projectedValue)
        .background(colour.projectedValue)
        .width(number.projectedValue)
        .height(number.projectedValue)
        .minimumWidth(number.projectedValue)
        .minimumHeight(number.projectedValue)
        .maximumWidth(number.projectedValue)
        .maximumHeight(number.projectedValue)
        .rotation(number.projectedValue)
        .rotationX(number.projectedValue)
        .rotationY(number.projectedValue)
        .scale(number.projectedValue)
        .scaleX(number.projectedValue)
        .scaleY(number.projectedValue)
        .translationX(number.projectedValue)
        .translationY(number.projectedValue)
        .pivotX(number.projectedValue)
        .pivotY(number.projectedValue)
        .margin(inset.projectedValue)
        .padding(inset.projectedValue)
        .strokeWidth(number.projectedValue)

        let shape = Rectangle()
            .strokeWidth(number.projectedValue)
            .strokeDashOffset(number.projectedValue)
            .strokeMiterLimit(number.projectedValue)

        // A Button for the outline the mixin is about, and a TextField for the
        // placeholder - neither of them a layout's.
        let button = Button("press")
            .borderColor(colour.projectedValue)
            .borderWidth(number.projectedValue)

        let entry = TextField("").placeholderColor(colour.projectedValue)

        // And the one modifier that is a control's own rather than a tier's.
        let box = ColorBox().color(colour.projectedValue)

        let page = try page(VStack { border; shape; button; entry; box }.spacing(number.projectedValue).body)

        // The number is state 1, the colour 2 and the insets 3, in the walk.
        XCTAssertEqual(ties(page, .auto(3)), tied(["spacing"], to: 1, .inOut, .property))
        XCTAssertEqual(
            ties(page, .auto(3), .auto(4)),
            tied([
                "height", "maximumHeight", "maximumWidth", "minimumHeight", "minimumWidth", "opacity",
                "pivotX", "pivotY", "rotation", "rotationX", "rotationY", "scale", "scaleX", "scaleY",
                "strokeWidth", "translationX", "translationY", "width",
            ], to: 1, .inOut, .property)
                .merging(tied(["background"], to: 2, .inOut, .property)) { $1 }
                .merging(tied(["margin", "padding"], to: 3, .inOut, .property)) { $1 })
        XCTAssertEqual(
            ties(page, .auto(3), .auto(4), .auto(5)),
            tied(["characterSpacing", "fontSize"], to: 1, .inOut, .property)
                .merging(tied(["textColor"], to: 2, .inOut, .property)) { $1 })
        XCTAssertEqual(
            ties(page, .auto(3), .auto(6)),
            tied(["strokeDashOffset", "strokeMiterLimit", "strokeWidth"], to: 1, .inOut, .property))
        XCTAssertEqual(
            ties(page, .auto(3), .auto(7)),
            tied(["borderWidth"], to: 1, .inOut, .property)
                .merging(tied(["borderColor"], to: 2, .inOut, .property)) { $1 })
        XCTAssertEqual(ties(page, .auto(3), .auto(8)), tied(["placeholderColor"], to: 2, .inOut, .property))
        XCTAssertEqual(ties(page, .auto(3), .auto(9)), tied(["color"], to: 2, .inOut, .property))
    }

    /// Text, which has no lanes and no journey: it is written when it changes
    /// and never walked to.
    func testDrivenTextRegistersTheTextChannel() throws {
        let caption = State(wrappedValue: "60%")

        let page = try page(VStack { Label().text(caption.projectedValue); Button().text(caption.projectedValue) }.body)

        XCTAssertEqual(ties(page, .auto(3), .auto(4)), tied(["text"], to: 1, .out, .text))
        XCTAssertEqual(ties(page, .auto(3), .auto(5)), tied(["text"], to: 1, .out, .text))
        XCTAssertNil(page.at(.auto(3), .auto(4))?.props["text"], "and no value beside it")
    }

    /// A field the user types into: the same text door, both ways.
    func testATwoWayTextRegistersBothWays() throws {
        let name = State(wrappedValue: "Ada")

        let page = try page(VStack {
            // A handler BESIDE the state, so the host side can prove the
            // state's own words raise no event.
            TextField(name.projectedValue).onTextChanged { _ in }
            TextEditor(name.projectedValue)
            SearchField(name.projectedValue)
        }.body)

        for field in [ElementId.auto(4), .auto(5), .auto(6)] {
            XCTAssertEqual(ties(page, .auto(3), field), tied(["text"], to: 1, .inOut, .text))
        }
        XCTAssertEqual(page.at(.auto(3), .auto(4))?.eventNames, ["textChanged"])
    }

    /// A day and a time the user picks: three lanes each, plain, both ways.
    func testAPickedDayAndTimeRegisterPlainBothWays() throws {
        let due = State(wrappedValue: CalendarDate(year: 2026, month: 8, day: 2))
        let alarm = State(wrappedValue: ClockTime(hour: 9, minute: 30, second: 5))

        let page = try page(VStack {
            DatePicker(due.projectedValue).onDateChanged { _ in }
            TimePicker(alarm.projectedValue)
        }.body)

        XCTAssertEqual(ties(page, .auto(3), .auto(4)), tied(["date"], to: 1, .inOut, .plain))
        XCTAssertEqual(page.at(.auto(3), .auto(4))?.eventNames, ["dateChanged"])
        XCTAssertEqual(ties(page, .auto(3), .auto(5)), tied(["time"], to: 2, .inOut, .plain))
    }

    /// The two-way inputs, whose value the user can move as well.
    func testADrivenInputRegistersAJourney() throws {
        let level = State(wrappedValue: 0.5)
        let steps = State(wrappedValue: 3.0)

        let page = try page(VStack {
            Slider().value(level.projectedValue)
            Stepper().value(steps.projectedValue)
        }.body)

        XCTAssertEqual(ties(page, .auto(3), .auto(4)), tied(["value"], to: 1, .inOut, .property))
        XCTAssertEqual(ties(page, .auto(3), .auto(5)), tied(["value"], to: 2, .inOut, .property))
    }

    /// ONE STATE, TWO SINKS: a value the user drags and a size that rides the
    /// same number.
    ///
    /// The pair is what a report has to reach BOTH of - the control the user
    /// touched already shows the new value, and the other one has heard
    /// nothing at all unless somebody tells it.
    func testTwoControlsCanRideOneDrivenValue() throws {
        let level = State(wrappedValue: 0.5)

        let page = try page(VStack {
            Slider().value(level.projectedValue)
            ColorBox().width(level.projectedValue)
        }.body)

        XCTAssertEqual(ties(page, .auto(3), .auto(4)), tied(["value"], to: 1, .inOut, .property))
        XCTAssertEqual(ties(page, .auto(3), .auto(5)), tied(["width"], to: 1, .inOut, .property))
    }

    /// A LAYOUT PLACED BY DRIVEN STATE, which says where its views go and nothing
    /// else: one registration on the layout, and not one of the twelve
    /// properties of a placement on any child of it.
    ///
    /// The wrapper around each face is the library's own and is always there,
    /// shaded or not - which is what keeps the host's writes off the author's
    /// view. A shaded run wraps two, the shade second.
    func testADrivenPlacedLayoutRegistersOnTheLayoutAlone() throws {
        let run = State(wrappedValue: PlacedRun())
        let room = State(wrappedValue: Rect(0, 0, 0, 0))

        let page = try page(
            PlacedLayout(["a", "b"], id: \.self) { Label($0) }
                .shade(ColorBox(.black))
                .placement(run.projectedValue)
                .frame(room.projectedValue)
                .body)
        let layout = try XCTUnwrap(page.at(.auto(3)))

        XCTAssertEqual(
            ties(page, .auto(3)),
            tied(["area"], to: 1, .out, .placement)
                .merging(tied(["frame"], to: 2, .in, .feed)) { $1 })
        XCTAssertEqual(layout.arrangement, [.manual("a"), .manual("b")])
        XCTAssertEqual(layout.children.map(\.type), [.grid, .grid], "the library's wrapper around each face")
        XCTAssertEqual(layout.children.map(\.children.count), [2, 2], "the face, then its shade")
        XCTAssertTrue(
            layout.children.flatMap(\.subtree).allSatisfy { $0.driven == nil },
            "not one property of a placement on any child")
    }

    /// THE NUMBERS ARE THE WALK'S, and within one element the property NAMES':
    /// asking a state for its number is what issues one, and a Dictionary has no
    /// order at all - Swift salts its hashing per process, so numbering them as
    /// they happen to be stored would give one tree different numbers in two
    /// runs, and a test names them.
    ///
    /// Written the other way round from the order they come out in, so the
    /// sort is what the assertion is about.
    func testTwoDrivenPropertiesOnOneElementNumberInTheOrderTheirNamesDo() {
        let moved = State(wrappedValue: 0.0)
        let faded = State(wrappedValue: 1.0)
        let differ = Differ()

        _ = differ.reconcile(
            nil,
            with: rooted(Label("x").translationX(moved.projectedValue).opacity(faded.projectedValue).body))

        XCTAssertEqual(faded.number, 1, "opacity sorts before translationX")
        XCTAssertEqual(moved.number, 2)
    }

    // MARK: - The guards

    /// EVERY PROPERTY THE HOST WALKS IS ONE THE TREE CAN DESCRIBE, over a value
    /// the host has a blend for.
    ///
    /// A walked twin for a property nothing declares, or over a value nothing
    /// interpolates, would compile and then do nothing at all - which is the
    /// one failure this library refuses to ship. Read off the source: every
    /// `journey(.x, by:)` - or `journey(SomeContract.x, by:)`, the member with
    /// its contract - under a `public func x(_ state: Binding<T>)`.
    func testEveryWalkedModifierNamesACarriedPropertyOfTheSameName() throws {
        let sources = try SourceTree.allSources()

        var walked: [(name: String, type: String)] = []
        var values: Set<String> = []

        for source in sources {
            var signature: (name: String, type: String)?

            // Line by line, deliberately: a scan over a whole file would read
            // from one declaration's "public func " to a LATER one's and come
            // back with everything in between.
            for line in source.text.split(separator: "\n") {
                let written = String(line)

                values.formUnion(written.occurrences(between: "public func ", and: "(_ value:"))

                if let name = written.occurrences(between: "public func ", and: "(").first,
                   let type = written.occurrences(between: "Binding<", and: ">").first {
                    signature = (name, type)
                } else if let property = written.occurrences(between: "journey(", and: ",").first,
                          property.hasPrefix(".")
                            || property.split(separator: ".").first?.hasSuffix("Contract") == true,
                          let signature {
                    walked.append(signature)
                }
            }
        }

        XCTAssertGreaterThan(
            walked.count, 20, "the scan found too few walked modifiers to be reading the right thing")

        // What the host has a blend for, and the whole of it - a number, a
        // colour, a thickness, and a POINT, which is the scroller's offset:
        // two lanes the host carries by the scroller's own key rather than by
        // a property's type, the platform declaring no settable property for
        // it.
        let carried: Set<String> = ["Double", "Color", "Insets", "Point"]

        // THE ONE WALKED MODIFIER WITH NO DESCRIBED TWIN. A scroller's offset
        // is a property the platform keeps read-only - a scroller reports
        // where it stands and has no setter worth writing to - so there is nothing for
        // the tree to describe and the state is its only spelling, both ways.
        let stateOnly: Set<String> = ["scrollOffset"]

        for modifier in walked {
            XCTAssertTrue(
                carried.contains(modifier.type),
                "`\(modifier.name)` is walked from \(modifier.type), which nothing carries")
            XCTAssertTrue(
                values.contains(modifier.name) || stateOnly.contains(modifier.name),
                "`\(modifier.name)` is walked but no modifier of that name takes a value")
        }
    }

    /// ONE SPELLING PER ROAD, and `move(to:_:)` is the JOURNEY's.
    ///
    /// A value the HOST walks is SENT - `$fade.journey.move(to: …)`, awaited,
    /// because there is something walking it to answer when it arrives. A
    /// value the TREE holds is moved by ASSIGNMENT: the differ writes a
    /// transition beside it and the host carries the control there, with
    /// nobody waiting.
    ///
    /// Read from the source rather than written out here, because what this
    /// holds is that no SECOND declaration comes back - on `Binding`, say, as
    /// a synonym for assignment that answered `true` for a walk nothing
    /// walked - and that the old spelling stays gone.
    func testAValueIsSentOnAJourneyByOneSpellingOnly() throws {
        let sources = try SourceTree.allSources()
        var declared: [(file: String, line: String)] = []
        var old = 0

        for source in sources {
            for line in source.text.split(separator: "\n") {
                if line.contains("func move(to") {
                    declared.append(
                        (source.path, String(line).trimmingCharacters(in: .whitespacesAndNewlines)))
                }

                if line.contains("func animateTo") { old += 1 }
            }
        }

        XCTAssertEqual(declared.count, 1, "one declaration, and it is the journey's: \(declared)")
        XCTAssertEqual(
            declared.first.map { SourceTree.name(of: $0.file) }, "Journey.swift",
            "the one that survives lives beside the journey")
        XCTAssertTrue(
            declared.first?.line.contains("target: Value") == true,
            "and it takes the value's own type: it is the journey's, not any binding's")
        XCTAssertEqual(old, 0, "`animateTo` is not a spelling any more")
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

        let number = State(wrappedValue: 0.5)
        let flag = State(wrappedValue: true)

        same(Slider(number.projectedValue).node,
             Slider().value(number.projectedValue).node, "Slider.value")
        same(Stepper(number.projectedValue).node,
             Stepper().value(number.projectedValue).node, "Stepper.value")
        same(Switch(flag.projectedValue).node,
             Switch().isOn(flag.projectedValue).node, "Switch.isOn")
        same(CheckBox(flag.projectedValue).node,
             CheckBox().isOn(flag.projectedValue).node, "CheckBox.isOn")
    }

    /// AND SO IS A DRIVEN ONE: `Slider($level)` says exactly what
    /// `Slider().value($level)` says - over a `Journey`, and over a
    /// plain `Double`, which the host carries as a journey too. An author
    /// writes `Slider($x)` and the host walks it either way; what the
    /// declaration says is what can be read back.
    func testADrivenPurposeValueIsWritableBothWays() {
        Renderer.shared.clearStates()

        let level = State(wrappedValue: 0.5)
        let steps = State(wrappedValue: 3.0)

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

        // And over a plain `Double`, which the host walks as a journey too.
        let plain = State(wrappedValue: 0.5)

        registers(Slider(plain.projectedValue),
                  Slider().value(plain.projectedValue), "Slider over a Double")
        registers(Stepper(plain.projectedValue),
                  Stepper().value(plain.projectedValue), "Stepper over a Double")

        // The fields and the pickers, which the host carries both ways too.
        let text = State(wrappedValue: "a")
        let due = State(wrappedValue: CalendarDate(year: 2026, month: 8, day: 2))
        let alarm = State(wrappedValue: ClockTime(hour: 9, minute: 30))

        registers(TextField(text.projectedValue), TextField().text(text.projectedValue), "TextField")
        registers(TextEditor(text.projectedValue), TextEditor().text(text.projectedValue), "TextEditor")
        registers(SearchField(text.projectedValue), SearchField().text(text.projectedValue), "SearchField")
        registers(DatePicker(due.projectedValue), DatePicker().date(due.projectedValue), "DatePicker")
        registers(TimePicker(alarm.projectedValue), TimePicker().time(alarm.projectedValue), "TimePicker")
    }
}
