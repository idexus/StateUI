// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A host's realization, registered contract by contract and exercised with a
// test double for a platform view: views made through their registration,
// properties handed over as their declared types - one at a time, or the
// element whole where a view takes several at once - an element's own events
// raised by member and its user's values reported by member, what a host's
// shared machinery realizes on every element wearing a tier, and what the host
// realizes told to the core.

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
        var dialled: ((Int) -> Void)?
        var tuned: ((Double) -> Void)?
        var strayed: ((Double) -> Void)?
    }

    /// Something that is no platform view - what a registration must not make.
    private final class Stray {}

    /// What the element's reports handed on.
    private final class Told {
        var events: [String] = []
        var values: [String] = []
    }

    override func tearDown() {
        StateUIHost.setRealization(HostRealization())
        super.tearDown()
    }

    /// A registered contract makes its view, the class its registration makes;
    /// a node type nothing registered makes none, and is the caller's to show.
    func testARegisteredContractMakesItsView() {
        let registry = Self.lamps()

        XCTAssertTrue(Self.view(of: LampContract.nodeType, in: registry) is LampView)
        XCTAssertNil(Self.view(of: LabelContract.nodeType, in: registry))
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
        let told = Told()
        let view = try XCTUnwrap(Self.view(of: LampContract.nodeType, in: registry, told: told) as? LampView)

        view.tapped?(2)

        XCTAssertEqual(told.events, ["lampTapped \([2.propValue])"])
        XCTAssertTrue(told.values.isEmpty, "an event of its own carries no value of the element's")
    }

    /// A value the user changed is reported by member: the element is handed
    /// the property, the event to raise for it, and the value - so the host
    /// writes it where the value is carried and raises the event once.
    func testTheViewReportsItsUsersValueByMember() throws {
        let registry = Self.lamps()
        let told = Told()
        let view = try XCTUnwrap(Self.view(of: LampContract.nodeType, in: registry, told: told) as? LampView)

        view.dialled?(3)

        XCTAssertEqual(told.values, ["signal signalChanged \(3.propValue)"])
        XCTAssertTrue(told.events.isEmpty, "a reported value raises its event through the report")
    }

    /// A value and the change it reports may be declared on a TIER the element
    /// wears rather than on the element itself - which is how a field's words
    /// and its text change are written.
    func testAValueOfATierItWearsIsReportedAsThatTiersEvent() throws {
        let registry = Self.lamps()
        let told = Told()
        let view = try XCTUnwrap(Self.view(of: LampContract.nodeType, in: registry, told: told) as? LampView)

        view.tuned?(0.5)

        XCTAssertEqual(told.values, ["setting settingChanged \(0.5.propValue)"])
    }

    /// A member of a contract the element does not wear reports nothing at all,
    /// and is said once.
    func testAMemberOfAContractItDoesNotWearReportsNothing() throws {
        let registry = Self.lamps()
        let told = Told()
        let view = try XCTUnwrap(Self.view(of: LampContract.nodeType, in: registry, told: told) as? LampView)

        view.strayed?(0.5)

        XCTAssertTrue(told.values.isEmpty, "the lamp wears no StrayDial, so nothing is reported")
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

    /// An element the shared machinery does not reach is left out of what it realizes, though it wears the
    /// contract; every other wearer keeps it.
    func testAnElementTheSharedMachineryDoesNotReachIsLeftOut() {
        let registry = Self.lamps()

        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.translationX, except: [LampContract.nodeType])

        XCTAssertTrue(registry.realization.members.contains(
            HostRealizedMember(element: "Test.Lamp", owner: "VisualElement", member: "isVisible")))
        XCTAssertFalse(registry.realization.members.contains(
            HostRealizedMember(element: "Test.Lamp", owner: "VisualElement", member: "translationX")))
        XCTAssertEqual(registry.sharedNames, ["isVisible"], "a member some wearers lack is not every element's")
    }

    /// A registration that makes something no platform view is refused where
    /// the view would be made: nothing stands for the element.
    func testARegistrationMakingNoPlatformViewMakesNothing() {
        let registry = Registry<PlatformView>()

        registry.add(PlainContract.self, create: { _ in Stray() })

        XCTAssertNil(Self.view(of: PlainContract.nodeType, in: registry))
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

    /// An element whose VIEW THE HOST MAKES takes its members and records what
    /// it realizes, while the registry makes nothing for it: the host's own arm
    /// makes that view, where making it needs machinery no contract describes -
    /// a scroll view's user transaction and the frames it asks the host for.
    func testAnElementTheHostMakesTakesItsMembersAndMakesNoView() {
        let registry = Registry<PlatformView>()

        registry.add(LampContract.self, madeByHost: LampView.self) { lamp in
            lamp.property(LampContract.signal) { view, signal in view.signal = signal }
        }

        XCTAssertNil(
            Self.view(of: LampContract.nodeType, in: registry),
            "the host makes this view, so the registry makes none for it")
        XCTAssertTrue(
            registry.realization.elements.contains(LampContract.name),
            "the host realizes the element whoever makes its view")
        XCTAssertTrue(registry.realization.members.contains(
            HostRealizedMember(element: LampContract.name, owner: LampContract.name, member: "signal")))

        let view = LampView()
        let signal = LampContract.signal.token
        let applied = registry.apply(
            [signal], to: view, of: LampContract.nodeType, reading: { _ in 2.propValue })

        XCTAssertEqual(view.signal, 2, "the registration applies to the view the host made")
        XCTAssertEqual(applied, [signal])
    }

    // MARK: - Support

    /// A registry realizing the lamp: its signal and the opacity it wears one
    /// at a time, its caption and emphasis whole, the lamp tap it raises, the
    /// signal its user dials - and a member of a contract it does not wear,
    /// which the registry refuses.
    private static func lamps() -> Registry<PlatformView> {
        let registry = Registry<PlatformView>()

        registry.add(LampContract.self, create: { reports in
            let lamp = LampView()
            lamp.tapped = { index in reports.raise(LampContract.lampTapped, index) }
            lamp.dialled = { signal in
                reports.report(LampContract.signal, signal, as: LampContract.signalChanged)
            }
            lamp.tuned = { level in
                reports.report(DialContract.setting, level, as: DialContract.settingChanged)
            }
            lamp.strayed = { level in
                reports.report(StrayDialContract.setting, level, as: StrayDialContract.settingChanged)
            }
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

    /// A view of `type`, its reports written into `told`.
    private static func view(
        of type: NodeType, in registry: Registry<PlatformView>, told: Told = Told()
    ) -> PlatformView? {
        registry.makeView(
            for: type,
            sending: { event, values in told.events.append("\(event.name) \(values)") },
            reporting: { property, event, value in
                told.values.append("\(property.name) \(event.name) \(value)")
            })
    }

    /// The lamp's view, made by its registration.
    private static func lamp(_ registry: Registry<PlatformView>) throws -> LampView {
        try XCTUnwrap(view(of: LampContract.nodeType, in: registry) as? LampView)
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

/// A tier the lamp wears: a value and the change it reports, declared apart
/// from the element itself - as a field's words and its text change are.
private enum DialContract: Contract {
    static let name = "TestDial"

    static let setting = ElementProperty<Self, Double>("setting")
    static let settingChanged = ElementEvent<Self, Double>("settingChanged")

    static let members: [any ContractMember] = [setting, settingChanged]
}

/// The same shape, worn by nothing here.
private enum StrayDialContract: Contract {
    static let name = "StrayDial"

    static let setting = ElementProperty<Self, Double>("setting")
    static let settingChanged = ElementEvent<Self, Double>("settingChanged")

    static let members: [any ContractMember] = [setting, settingChanged]
}

/// An element a host realizes, declared the way an application declares its
/// own.
private enum LampContract: ElementContract {
    static let nodeType: NodeType = "Test.Lamp"
    static let tiers: [any Contract.Type] = [ViewContract.self, DialContract.self]

    static let signal = ElementProperty<Self, Int>("signal")
    static let caption = ElementProperty<Self, String>("caption")
    static let emphasis = ElementProperty<Self, Bool>("emphasis")
    static let unrealized = ElementProperty<Self, Bool>("unrealized")
    static let lampTapped = ElementEvent<Self, Int>("lampTapped")
    static let signalChanged = ElementEvent<Self, Int>("signalChanged")

    static let members: [any ContractMember] = [signal, caption, emphasis, unrealized, lampTapped, signalChanged]
}

/// An element wearing no tier.
private enum PlainContract: ElementContract {
    static let nodeType: NodeType = "Test.Plain"

    static let members: [any ContractMember] = []
}
