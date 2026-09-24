// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An element's contract, and the typed roads through it: a property written as
// its declared value, an event heard as its declared values, an act called and
// answered as its declared values - each refusing a value of another shape.

import XCTest
@_spi(Host) @testable import StateUI

final class ContractTests: XCTestCase {
    /// A place a handler writes - a plain class captured in a test method,
    /// which is the capture that stays on this library's executor.
    private final class Heard {
        var lines: [String] = []
    }

    // MARK: - The declaration

    /// An element's contract names its node type, and its name is that type's;
    /// an application's element is realized by the application unless it says.
    func testAContractNamesItsElementAndItsMembers() {
        XCTAssertEqual(LampContract.nodeType, "Test.Lamp")
        XCTAssertEqual(LampContract.name, "Test.Lamp")
        XCTAssertEqual(LampContract.layer, .provider)
        XCTAssertTrue(LampContract.tiers.isEmpty)
        XCTAssertEqual(LampContract.members.map(\.name), [
            "signal", "brightness", "caption", "count", "tapped", "dimmed", "poked", "Test.Flash",
        ])

        XCTAssertEqual(TestDevice.name, "Test")
        XCTAssertEqual(LampContract.signal.token, "signal")
        XCTAssertEqual(LampContract.tapped.token, "tapped")
        XCTAssertEqual(LampContract.flash.token, "Test.Flash")
    }

    // MARK: - A property

    /// A property crosses as the value its contract declares: a closed
    /// vocabulary as its member's number, a whole number as a number, nil as
    /// nothing.
    func testAPropertyCrossesAsItsDeclaredValue() {
        let lamp = Lamp()
            .setValue(LampContract.signal, .go)
            .setValue(LampContract.brightness, 0.5)
            .setValue(LampContract.caption, nil)
            .setValue(LampContract.count, 3)

        XCTAssertEqual(lamp.node.type, "Test.Lamp")
        XCTAssertEqual(lamp.node.props["signal"], .enumeration(2))
        XCTAssertEqual(lamp.node.props["brightness"], .number(0.5))
        XCTAssertEqual(lamp.node.props["caption"], .nothing)
        XCTAssertEqual(lamp.node.props["count"], .number(3))
    }

    /// What comes back from a host is the declared kind or no value at all -
    /// never a guess, and never a trap on a number that is not one.
    func testAValueBackFromTheHostIsTheDeclaredKindOrNone() {
        XCTAssertEqual(Int(propValue: .number(2.7)), 2)
        XCTAssertNil(Int(propValue: .number(.nan)))
        XCTAssertNil(Int(propValue: .number(.infinity)))
        XCTAssertNil(Int(propValue: .string("2")))
        XCTAssertEqual(LampSignal(propValue: .enumeration(1)), .caution)
        XCTAssertNil(LampSignal(propValue: .enumeration(7)))
        XCTAssertNil(LampSignal(propValue: .number(1)))
        XCTAssertEqual(String?(propValue: .nothing), .some(nil))
        XCTAssertTrue(String?(propValue: .number(1)) == nil, "a number is not text, nor nothing")
        XCTAssertNil(Bool(propValue: .string("true")))
    }

    /// A list crosses in the form its values' type gives it: numbers as one
    /// run, text as one list, points as one flat run of pairs.
    func testAListCrossesInItsValuesForm() {
        XCTAssertEqual([1.0, 2.5].propValue, .numbers([1, 2.5]))
        XCTAssertEqual(["a", "b"].propValue, .strings(["a", "b"]))
        XCTAssertEqual([Point(1, 2), Point(3, 4)].propValue, .numbers([1, 2, 3, 4]))

        XCTAssertEqual([Double](propValue: .numbers([1, 2])), [1, 2])
        XCTAssertEqual([Point](propValue: .numbers([1, 2, 3, 4])), [Point(1, 2), Point(3, 4)])
        XCTAssertNil([Point](propValue: .numbers([1, 2, 3])), "an odd run is not points")
        XCTAssertNil([String](propValue: .numbers([1])))
    }

    /// A name crosses as a name, never as prose - the type decides: a style
    /// key, a font family, a window's kind, a kept value's key alike.
    func testANameCrossesAsAName() {
        let lamp = Lamp().setValue(VisualElementContract.style, "Card")

        XCTAssertEqual(lamp.node.props["style"], .name("Card"))
        XCTAssertEqual(Name("Menlo").propValue, .name("Menlo"))
        XCTAssertEqual(Name(propValue: .name("Menlo")), "Menlo")
        XCTAssertNil(Name(propValue: .string("Menlo")), "prose is not a name")
        XCTAssertEqual(WindowType("document").propValue, .name("document"))
    }

    /// A shape, a grid's lengths, a web view's source and a drawing cross as
    /// their kind and then what that kind is made of; a kind without its
    /// parts, or one this library has none of, reads as no value.
    func testAKindCrossesInFrontOfItsParts() {
        XCTAssertEqual(BorderShape.roundedRectangle(12).propValue, .values([.enumeration(1), .number(12)]))
        XCTAssertEqual(BorderShape.ellipse.propValue, .values([.enumeration(2)]))
        XCTAssertEqual(
            [GridLength.auto, .fixed(100)].propValue,
            .values([.values([.enumeration(2), .number(1)]), .values([.enumeration(0), .number(100)])]))
        XCTAssertEqual(
            WebViewSource.url("https://example.com").propValue,
            .values([.enumeration(0), .string("https://example.com")]))
        XCTAssertEqual(
            WebViewSource.html("<p>Hi</p>", baseUrl: nil).propValue,
            .values([.enumeration(1), .string("<p>Hi</p>"), .nothing]))
        XCTAssertEqual(
            [Draw.fillColor(.gold)].propValue,
            .values([.values([.enumeration(0), Color.gold.propValue])]))

        XCTAssertNil(BorderShape(propValue: .values([.enumeration(1)])), "a rounded rectangle without its radius")
        XCTAssertNil(GridLength(propValue: .values([.enumeration(9), .number(1)])), "a kind with no member")
        XCTAssertNil(WebViewSource(propValue: .values([.enumeration(1), .string("<p/>")])), "two places, not three")
    }

    /// The unions cross exactly as their parts do, and read back.
    func testTheUnionsCrossAsTheirPartsDo() {
        XCTAssertEqual(CornerRadius.uniform(8).propValue, .number(8))
        XCTAssertEqual(
            CornerRadius.corners(topLeft: 1, topRight: 2, bottomLeft: 3, bottomRight: 4).propValue,
            .numbers([1, 2, 3, 4]))
        XCTAssertEqual(MapRegion(latitude: 52, longitude: 21, radiusMeters: 1500).propValue, .numbers([52, 21, 1500]))

        let brush = Brush.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)])

        XCTAssertEqual(Background.color(.tomato).propValue, Color.tomato.propValue)
        XCTAssertEqual(Background.brush(brush).propValue, brush.propValue)
        XCTAssertEqual(Background(propValue: Color.tomato.propValue), .color(.tomato))
        XCTAssertEqual(Background(propValue: brush.propValue), .brush(brush))

        XCTAssertEqual(SafeAreaEdges.uniform(.none).propValue, .enumeration(0))
        XCTAssertEqual(
            SafeAreaEdges.edges(left: .none, top: .container, right: .none, bottom: .container).propValue,
            .values([.enumeration(0), .enumeration(2), .enumeration(0), .enumeration(2)]))
        XCTAssertEqual(SafeAreaEdges(propValue: .enumeration(3)), .uniform(.all))
        XCTAssertEqual(
            SafeAreaEdges(propValue: .values([.enumeration(0), .enumeration(1), .enumeration(2), .enumeration(3)])),
            .edges(left: .none, top: .keyboard, right: .container, bottom: .all))
    }

    /// Every value a member holds comes back from its host form as itself -
    /// and every type a library property holds has a sample here, so a
    /// property of a type with none fails.
    func testEveryValueAMemberHoldsComesBackAsItself() {
        func comesBack<Value: HostRepresentable & Equatable>(_ value: Value) -> Bool {
            Value(propValue: value.propValue) == value
        }

        let samples: [any HostRepresentable & Equatable] = [
            true, 3, 0.5, "text", Name("Card"),
            Color.tomato, Color(light: .white, dark: .black),
            Brush.solidColor(.gold),
            Brush.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)]),
            Brush.radialGradient([GradientStop(.white, 0), GradientStop(.steelBlue, 1)], radius: 0.8),
            Background.color(.tomato), Background.brush(.linearGradient([GradientStop(.gold, 0)])),
            Insets(1, 2, 3, 4), Rect(1, 2, 3, 4), Point(5, 6),
            [Point(1, 2), Point(3, 4)] as [Point], [1, 2.5] as [Double], ["a", "b"] as [String],
            ImageSource("logo.png"), ImageSource(light: "logo.png", dark: "logo_dark.png"),
            ViewTransform.rotate(15).scaleX(1.2),
            SafeAreaEdges.uniform(.all),
            SafeAreaEdges.edges(left: .none, top: .container, right: .none, bottom: .container),
            CornerRadius.uniform(8), CornerRadius.corners(topLeft: 1, topRight: 2, bottomLeft: 3, bottomRight: 4),
            WebViewSource.url("https://example.com"), WebViewSource.html("<p/>", baseUrl: nil),
            WebViewSource.html("<p/>", baseUrl: "https://example.com"),
            MapRegion(latitude: 52.25, longitude: 21.01, radiusMeters: 1500),
            Location(latitude: 52.25, longitude: 21.01),
            CalendarDate(year: 2026, month: 9, day: 15), ClockTime(hour: 9, minute: 30, second: 5),
            BorderShape.rectangle, BorderShape.roundedRectangle(12), BorderShape.ellipse,
            [GridLength.auto, .proportional(2), .fixed(100)] as [GridLength],
            [Draw.fillColor(.gold)] as [DrawCommand],
            WindowType("document"),
            FontAttributes([.bold, .italic]), TextDecorations(rawValue: 1),
            AbsoluteLayoutProportions(rawValue: 3), SwipeDirection.all,
            Alignment(rawValue: 1)!, TextAlignment.center, LineBreak(rawValue: 1)!, TextCase(rawValue: 1)!,
            InputPurpose(rawValue: 1)!, ReturnKey(rawValue: 1)!, ScrollOrientation(rawValue: 1)!,
            PinType(rawValue: 1)!, Aspect(rawValue: 1)!, LayoutDirection(rawValue: 1)!,
            HeadingLevel(rawValue: 1)!, ScrollBarVisibility(rawValue: 1)!,
            LineCap(rawValue: 1)!, LineJoin(rawValue: 1)!,
            FillRule(rawValue: 1)!, IndicatorShape(rawValue: 1)!, ToolbarItemPlacement(rawValue: 1)!,
            SafeArea(rawValue: 1)!, IconPosition(rawValue: 1)!, MapType(rawValue: 1)!,
            WebNavigationEvent(rawValue: 1)!, WebNavigationResult(rawValue: 1)!, GesturePhase.running,
        ]

        for sample in samples {
            XCTAssertTrue(comesBack(sample), "\(sample) does not come back from \(sample.propValue) as itself")
        }

        let held = Set(samples.map { ObjectIdentifier(type(of: $0)) })
        var missing: [String] = []

        for contract in LibraryContracts.all {
            for case let member as any PropertyMember in contract.members
            where !held.contains(ObjectIdentifier(member.valueType)) {
                missing.append("\(contract.name).\(member.name) holds \(member.valueType)")
            }
        }

        XCTAssertEqual(missing, [], "a property holds a type with no sample here")
    }

    /// An optional value left off the end of a payload reads as nothing; a
    /// required one left off refuses the payload.
    func testAnOptionalLeftOffTheEndReadsAsNothing() {
        let omitted: Point?? = MemberValues.decode([], as: Point?.self)
        let given: Point?? = MemberValues.decode([.numbers([1, 2])], as: Point?.self)

        XCTAssertEqual(omitted, .some(nil))
        XCTAssertEqual(given, .some(Point(1, 2)))
        XCTAssertNil(MemberValues.decode([], as: Point.self), "a value the contract requires")
        XCTAssertEqual(MemberValues.decode([.number(1)], as: Int.self, String?.self).map { "\($0.0) \($0.1 ?? "-")" },
                       "1 -")
    }

    // MARK: - An event

    /// An event's values reach its handler as the types its contract
    /// declares, one parameter for each - none for an event with nothing to
    /// say.
    func testAnEventIsHeardAsItsDeclaredValues() throws {
        let heard = Heard()
        let renders = Renders()

        let patch = renders.render(Lamp()
            .onEvent(LampContract.tapped) { index in heard.lines.append("tapped \(index)") }
            .onEvent(LampContract.dimmed) { level, on in heard.lines.append("dimmed \(level) \(on)") }
            .onEvent(LampContract.poked) { heard.lines.append("poked") }
            .body)

        renders.fire(try XCTUnwrap(patch.events?["tapped"]), with: [.number(2)])
        renders.fire(try XCTUnwrap(patch.events?["dimmed"]), with: [.number(0.5), .bool(true)])
        renders.fire(try XCTUnwrap(patch.events?["poked"]))
        stateUIRunJobs()

        XCTAssertEqual(heard.lines, ["tapped 2", "dimmed 0.5 true", "poked"])
    }

    /// A payload of another shape - another kind, one value too many, one
    /// missing - is refused whole: the handler never runs on a guess.
    func testAPayloadOfAnotherShapeDoesNotReachTheHandler() throws {
        let heard = Heard()
        let renders = Renders()

        let patch = renders.render(Lamp()
            .onEvent(LampContract.tapped) { index in heard.lines.append("tapped \(index)") }
            .body)

        let id = try XCTUnwrap(patch.events?["tapped"])
        renders.fire(id, with: [.string("2")])
        renders.fire(id, with: [.number(2), .number(3)])
        renders.fire(id, with: [])
        stateUIRunJobs()

        XCTAssertEqual(heard.lines, [])
    }

    // MARK: - An act

    /// An application's act crosses with the arguments its contract declares
    /// and answers with the values it declares.
    func testAnApplicationActIsCalledAndAnsweredAsItsDeclaredValues() async throws {
        _ = drainedActs()

        let asked = await Self.begin { try await stateUICall(TestDevice.battery) }
        let acts = drainedActs()
        XCTAssertEqual(acts.first?.name, "Test.Battery")
        XCTAssertEqual(acts.first?.arguments, [])

        await report(try completionId(in: acts), .finished([.number(0.5), .bool(true)]))
        let (level, charging) = try await asked.value
        XCTAssertEqual(level, 0.5)
        XCTAssertTrue(charging)

        let copied = await Self.begin { try await stateUICall(TestDevice.copy, "note") }
        let copy = drainedActs()
        XCTAssertEqual(copy.first?.name, "Test.Copy")
        XCTAssertEqual(copy.first?.arguments, [.string("note")])

        await report(try completionId(in: copy), .finished([]))
        try await copied.value
    }

    /// An answer of another shape fails the call, naming the act and what its
    /// contract declares.
    func testAnAnswerOfAnotherShapeThrowsNamingTheAct() async throws {
        _ = drainedActs()

        let asked = await Self.begin { try await stateUICall(TestDevice.battery) }
        await report(try completionId(in: drainedActs()), .finished([.string("full")]))

        do {
            _ = try await asked.value
            XCTFail("an answer of another shape was taken")
        } catch let error as StateUIError {
            XCTAssertTrue(error.message.contains("Test.Battery"), error.message)
            XCTAssertTrue(error.message.contains("(Double, Bool)"), error.message)
        }
    }

    /// An act of an element's own goes through its aim: the element first,
    /// then the arguments its contract declares.
    func testAnAimedActPutsTheElementFirst() async throws {
        let renders = Renders()
        let lamp = Aim(Lamp.self)

        renders.render(stack([Lamp().aim(lamp).body], id: "root"))
        _ = drainedActs()

        let asked = await Self.begin { try await lamp.call(LampContract.flash, 3) }
        let acts = drainedActs()
        XCTAssertEqual(acts.first?.name, "Test.Flash")
        XCTAssertEqual(acts.first?.arguments, [.number(1), .number(3)], "the element it was put on, then the times")

        await report(try completionId(in: acts), .finished([.bool(true)]))
        let flashed = try await asked.value
        XCTAssertTrue(flashed)
    }

    // MARK: - An application's event

    /// An event with no control behind it is heard as its declared values,
    /// and a raise of another shape does not reach the handler.
    func testAnApplicationEventIsHeardAsItsDeclaredValues() {
        let heard = Heard()
        let subscription = HostEvents.on(TestDevice.batteryChanged) { level, charging in
            heard.lines.append("battery \(level) \(charging)")
        }
        defer { subscription.cancel() }

        XCTAssertEqual(HostEvents.dispatch("Test.BatteryChanged", [.number(0.87), .bool(true)]), 1)
        XCTAssertEqual(HostEvents.dispatch("Test.BatteryChanged", [.number(0.87)]), 1)
        stateUIRunJobs()

        XCTAssertEqual(heard.lines, ["battery 0.87 true"])
    }

    // MARK: - Support

    /// What a handler's body is, when it gives an answer back.
    ///
    /// Spelled as an alias because `nonisolated(nonsending)` cannot be written
    /// inline in a parameter type - the same reason EventHandler exists.
    private typealias Asking<Value> = nonisolated(nonsending) () async throws -> Value

    /// Starts an act and lets it reach its suspension, the way an event does:
    /// by the time this returns the act is on the act queue.
    @MainActor
    private static func begin<Value: Sendable>(_ body: sending @escaping Asking<Value>) -> Task<Value, Error> {
        Task.immediate { @MainActor in try await body() }
    }

    /// The completion id in a taken batch, which is what the host quotes back.
    private func completionId(in acts: [HostActCall]) throws -> Int {
        try XCTUnwrap(acts.compactMap(\.completion).first, "no completion id in \(PatchDump.text(acts))")
    }

    /// What the host does when it has finished an act: report the outcome, then
    /// run the work the resume produces.
    private func report(_ id: Int, _ reply: Reply) async {
        ReplyBuffer.current = reply
        if Renderer.shared.dispatch(id) { await settle() }
    }
}

/// A lamp of the application's own, declared the way an application declares
/// one.
private enum LampContract: ElementContract {
    static let nodeType: NodeType = "Test.Lamp"

    static let signal = ElementProperty<Self, LampSignal>("signal")
    static let brightness = ElementProperty<Self, Double>("brightness")
    static let caption = ElementProperty<Self, String?>("caption")
    static let count = ElementProperty<Self, Int>("count")
    static let tapped = ElementEvent<Self, Int>("tapped")
    static let dimmed = ElementEvent<Self, (Double, Bool)>("dimmed")
    static let poked = ElementEvent<Self, Void>("poked")
    static let flash = ElementAct<Self, Int, Bool>("Test.Flash")

    static let members: [any ContractMember] = [
        signal, brightness, caption, count, tapped, dimmed, poked, flash,
    ]
}

/// What the lamp shows: a closed vocabulary, crossing as its member's number.
private enum LampSignal: Int32, HostRepresentable {
    case stop, caution, go
}

/// The application's own acts and events with no control behind them.
private enum TestDevice: ApplicationTier {
    static let name = "Test"

    static let battery = ElementAct<Self, Void, (Double, Bool)>("Test.Battery")
    static let copy = ElementAct<Self, String, Void>("Test.Copy")
    static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Test.BatteryChanged")

    static let members: [any ContractMember] = [battery, copy, batteryChanged]
}

/// The lamp's view: its node from its contract.
private struct Lamp: View {
    var node = Node(contract: LampContract.self)
}
