// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A host's realization, registered contract by contract and exercised with a
// test double for a platform view: views made through their registration,
// properties handed over as their declared types - one at a time, or the
// element whole where a view takes several at once - an element's own events
// raised by member, what a host's shared machinery realizes on every element
// wearing a tier, and what the host realizes told to the core.

import XCTest
@_spi(Host) @testable import StateUI

final class RegistryTests: XCTestCase {
    /// A platform view, as far as a registry can tell: what every view it
    /// makes descends from.
    private class PlatformView {}

    /// A lamp's view, holding what its registration put on it.
    private final class LampView: PlatformView {
        var signal: Int?
        var opacity: Double?
        var caption = ""
        var captions = 0
        var tapped: ((Int) -> Void)?
    }

    /// Something that is no platform view - what a registration must not make.
    private final class Stray {}

    /// What a raise handed on.
    private final class Sent {
        var events: [String] = []
    }

    override func tearDown() {
        StateUIHost.setRealization(HostRealization())
        super.tearDown()
    }

    /// A registered contract makes its view, the class its registration makes;
    /// a node type nothing registered makes none, and is the caller's to show.
    func testARegisteredContractMakesItsView() {
        let registry = Self.lamps()

        XCTAssertTrue(registry.makeView(for: LampContract.nodeType) { _, _ in } is LampView)
        XCTAssertNil(registry.makeView(for: LabelContract.nodeType) { _, _ in })
    }

    /// A property registered alone reaches the view as the type its contract
    /// declares, and a value no longer described reaches it as nil.
    func testAPropertyReachesTheViewAsItsDeclaredType() throws {
        let registry = Self.lamps()
        let view = try Self.lamp(registry)
        let signal = LampContract.signal.token

        let applied = Self.apply([signal: 2.propValue], changed: [signal], to: view, in: registry)

        XCTAssertEqual(view.signal, 2)
        XCTAssertEqual(applied, [signal])

        Self.apply([:], changed: [signal], to: view, in: registry)

        XCTAssertNil(view.signal)
    }

    /// A value that crossed as another kind leaves the view as it was - said
    /// once, never guessed at.
    func testAValueOfAnotherKindLeavesTheView() throws {
        let registry = Self.lamps()
        let view = try Self.lamp(registry)
        let signal = LampContract.signal.token

        Self.apply([signal: 1.propValue], changed: [signal], to: view, in: registry)
        Self.apply([signal: .string("red")], changed: [signal], to: view, in: registry)

        XCTAssertEqual(view.signal, 1)
    }

    /// A property nothing registered is left to the caller: the answer names
    /// only the ones a registration took.
    func testAPropertyNothingRegisteredIsTheCallers() throws {
        let registry = Self.lamps()
        let view = try Self.lamp(registry)
        let visible = VisualElementContract.isVisible.token
        let signal = LampContract.signal.token

        let applied = Self.apply(
            [visible: .bool(false), signal: 0.propValue], changed: [visible, signal], to: view, in: registry)

        XCTAssertEqual(applied, [signal])
    }

    /// A member of a tier the contract wears registers; a member of a contract
    /// it does not wear is refused, and the realization does not claim it.
    func testATierItWearsRegistersAndAForeignMemberDoesNot() throws {
        let registry = Self.lamps()
        let view = try Self.lamp(registry)
        let opacity = VisualElementContract.opacity.token

        Self.apply([opacity: .number(0.5)], changed: [opacity], to: view, in: registry)

        XCTAssertEqual(view.opacity, 0.5)
        XCTAssertTrue(registry.realization.members.contains(
            HostRealizedMember(element: "Test.Lamp", owner: "VisualElement", member: "opacity")))
        XCTAssertFalse(registry.realization.members.contains { $0.member == "maximumLines" })
    }

    /// The view raises an event of its own by member: the raise hands the
    /// event's key and its values, encoded, to the element's sender.
    func testTheViewRaisesItsOwnEventByMember() throws {
        let registry = Self.lamps()
        let sent = Sent()
        let view = try XCTUnwrap(registry.makeView(for: LampContract.nodeType) { event, values in
            sent.events.append("\(event.name) \(values)")
        } as? LampView)

        view.tapped?(2)

        XCTAssertEqual(sent.events, ["lampTapped \([2.propValue])"])
    }

    /// A view taking several members at once is applied whole, once, when any
    /// of them changes - and not at all when none of them does.
    func testTheElementIsAppliedWholeWhenOneOfItsMembersChanges() throws {
        let registry = Self.lamps()
        let view = try Self.lamp(registry)
        let caption = LampContract.caption.token
        let emphasis = LampContract.emphasis.token
        let current: [Prop: HostValue] = [caption: .string("go"), emphasis: .bool(true)]

        let applied = Self.apply(current, changed: [caption, emphasis], to: view, in: registry)

        XCTAssertEqual(view.caption, "go!")
        XCTAssertEqual(view.captions, 1, "applied whole once, not once a member")
        XCTAssertEqual(applied, [caption, emphasis])

        Self.apply(current, changed: [LampContract.signal.token], to: view, in: registry)

        XCTAssertEqual(view.captions, 1, "a change of none of its members leaves it")
    }

    /// The values a whole applier reads are typed by member, say what
    /// changed, and read as nil where a member is not described or crossed as
    /// another kind.
    func testTheValuesAWholeApplierReadsAreTypedByMember() {
        let caption = LampContract.caption.token
        let emphasis = LampContract.emphasis.token
        let current: [Prop: HostValue] = [caption: .string("stop")]
        let values = ElementValues<LampContract>(changed: [caption], reading: { current[$0] })

        XCTAssertEqual(values[LampContract.caption], "stop")
        XCTAssertNil(values[LampContract.emphasis])
        XCTAssertTrue(values.changed(LampContract.caption))
        XCTAssertFalse(values.changed(LampContract.emphasis))

        let crossing: [Prop: HostValue] = [emphasis: .string("yes")]
        let crossed = ElementValues<LampContract>(changed: [emphasis], reading: { crossing[$0] })

        XCTAssertNil(crossed[LampContract.emphasis], "a value of another kind is no value")
    }

    /// What a host's shared machinery realizes stands on every registered
    /// element wearing its contract, and on no element that does not.
    func testWhatTheSharedMachineryRealizesIsOnEveryElementWearingItsTier() {
        let registry = Self.lamps()

        registry.add(PlainContract.self, create: { _ in PlatformView() })
        registry.everyElementRealizes(VisualElementContract.isVisible)

        XCTAssertTrue(registry.realization.members.contains(
            HostRealizedMember(element: "Test.Lamp", owner: "VisualElement", member: "isVisible")))
        XCTAssertFalse(registry.realization.members.contains(
            HostRealizedMember(element: "Test.Plain", owner: "VisualElement", member: "isVisible")))
    }

    /// A registration that makes something no platform view is refused where
    /// the view would be made: nothing stands for the element.
    func testARegistrationMakingNoPlatformViewMakesNothing() {
        let registry = Registry<PlatformView>()

        registry.add(PlainContract.self, create: { _ in Stray() })

        XCTAssertNil(registry.makeView(for: PlainContract.nodeType) { _, _ in })
    }

    /// The core answers what the host realizes once the host has said it -
    /// an element, a property on it, an event it raises - and nothing it did
    /// not say.
    func testTheCoreAnswersWhatTheHostRealizes() {
        XCTAssertFalse(StateUIHost.realizes(LampContract.self), "nothing is realized before the host says")

        StateUIHost.setRealization(Self.lamps().realization)

        XCTAssertTrue(StateUIHost.realizes(LampContract.self))
        XCTAssertFalse(StateUIHost.realizes(LabelContract.self))
        XCTAssertTrue(StateUIHost.realizes(LampContract.signal))
        XCTAssertTrue(StateUIHost.realizes(LampContract.lampTapped))
        XCTAssertFalse(StateUIHost.realizes(LampContract.unrealized))
    }

    // MARK: - Support

    /// A registry realizing the lamp: its signal and the opacity it wears one
    /// at a time, its caption and emphasis whole, the lamp tap it raises - and
    /// a member of a contract it does not wear, which the registry refuses.
    private static func lamps() -> Registry<PlatformView> {
        let registry = Registry<PlatformView>()

        registry.add(LampContract.self, create: { raise in
            let lamp = LampView()
            lamp.tapped = { index in raise(LampContract.lampTapped, index) }
            return lamp
        }, members: { lamp in
            lamp.property(LampContract.signal) { view, signal in view.signal = signal }
            lamp.property(VisualElementContract.opacity) { view, opacity in view.opacity = opacity }
            lamp.property(LabelContract.maximumLines) { _, _ in }
            lamp.applies([LampContract.caption, LampContract.emphasis]) { view, values in
                view.caption = (values[LampContract.caption] ?? "")
                    + (values[LampContract.emphasis] == true ? "!" : "")
                view.captions += 1
            }
            lamp.raises(LampContract.lampTapped)
        })

        return registry
    }

    /// The lamp's view, made by its registration.
    private static func lamp(_ registry: Registry<PlatformView>) throws -> LampView {
        try XCTUnwrap(registry.makeView(for: LampContract.nodeType) { _, _ in } as? LampView)
    }

    /// Puts what changed on the lamp's view, the element's current values
    /// being `values`.
    @discardableResult
    private static func apply(
        _ values: [Prop: HostValue], changed: Set<Prop>, to view: LampView, in registry: Registry<PlatformView>
    ) -> Set<Prop> {
        registry.apply(changed, to: view, of: LampContract.nodeType, reading: { values[$0] })
    }
}

/// An element a host realizes, declared the way an application declares its
/// own.
private enum LampContract: ElementContract {
    static let nodeType: NodeType = "Test.Lamp"
    static let tiers: [any Contract.Type] = [ViewContract.self]

    static let signal = ElementProperty<Self, Int>("signal")
    static let caption = ElementProperty<Self, String>("caption")
    static let emphasis = ElementProperty<Self, Bool>("emphasis")
    static let unrealized = ElementProperty<Self, Bool>("unrealized")
    static let lampTapped = ElementEvent<Self, Int>("lampTapped")

    static let members: [any ContractMember] = [signal, caption, emphasis, unrealized, lampTapped]
}

/// An element wearing no tier.
private enum PlainContract: ElementContract {
    static let nodeType: NodeType = "Test.Plain"

    static let members: [any ContractMember] = []
}
