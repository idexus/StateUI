// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A host's realization, registered contract by contract and exercised with a
// test double for a platform view: views made through their registration,
// properties handed over as their declared types, an element's own events
// raised by member, and what the host realizes told to the core.

import XCTest
@_spi(Host) @testable import StateUI

final class RegistryTests: XCTestCase {
    /// A platform view, as far as a registry can tell: a class holding what its
    /// registration put on it.
    private final class LampView {
        var signal: Int?
        var opacity: Double?
        var tapped: ((Int) -> Void)?
    }

    /// What a raise handed on.
    private final class Sent {
        var events: [String] = []
    }

    override func tearDown() {
        StateUIHost.setRealization(HostRealization())
        super.tearDown()
    }

    /// A registered contract makes its view; a node type nothing registered
    /// makes none, and is the caller's to show.
    func testARegisteredContractMakesItsView() {
        let registry = Self.lamps()

        XCTAssertNotNil(registry.makeView(for: LampContract.nodeType) { _, _ in })
        XCTAssertNil(registry.makeView(for: LabelContract.nodeType) { _, _ in })
    }

    /// A property reaches the view as the type its contract declares, and a
    /// value no longer described reaches it as nil.
    func testAPropertyReachesTheViewAsItsDeclaredType() throws {
        let registry = Self.lamps()
        let view = try XCTUnwrap(registry.makeView(for: LampContract.nodeType) { _, _ in })

        let applied = registry.apply([LampContract.signal.token: 2.propValue], to: view, of: LampContract.nodeType)

        XCTAssertEqual(view.signal, 2)
        XCTAssertEqual(applied, [LampContract.signal.token])

        registry.apply([LampContract.signal.token: nil], to: view, of: LampContract.nodeType)

        XCTAssertNil(view.signal)
    }

    /// A value that crossed as another kind leaves the view as it was - said
    /// once, never guessed at.
    func testAValueOfAnotherKindLeavesTheView() throws {
        let registry = Self.lamps()
        let view = try XCTUnwrap(registry.makeView(for: LampContract.nodeType) { _, _ in })

        registry.apply([LampContract.signal.token: 1.propValue], to: view, of: LampContract.nodeType)
        registry.apply([LampContract.signal.token: .string("red")], to: view, of: LampContract.nodeType)

        XCTAssertEqual(view.signal, 1)
    }

    /// A property nothing registered is left to the caller: the answer names
    /// only the ones a registration took.
    func testAPropertyNothingRegisteredIsTheCallers() throws {
        let registry = Self.lamps()
        let view = try XCTUnwrap(registry.makeView(for: LampContract.nodeType) { _, _ in })

        let applied = registry.apply(
            [VisualElementContract.isVisible.token: .bool(false), LampContract.signal.token: 0.propValue],
            to: view, of: LampContract.nodeType)

        XCTAssertEqual(applied, [LampContract.signal.token])
    }

    /// A member of a tier the contract wears registers; a member of a contract
    /// it does not wear is refused, and the realization does not claim it.
    func testATierItWearsRegistersAndAForeignMemberDoesNot() throws {
        let registry = Self.lamps()
        let view = try XCTUnwrap(registry.makeView(for: LampContract.nodeType) { _, _ in })

        registry.apply([VisualElementContract.opacity.token: .number(0.5)], to: view, of: LampContract.nodeType)

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
        })

        view.tapped?(2)

        XCTAssertEqual(sent.events, ["lampTapped \([2.propValue])"])
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

    /// A registry realizing the lamp: its signal, the opacity it wears, the
    /// lamp tap it raises - and a member of a contract it does not wear,
    /// which the registry refuses.
    private static func lamps() -> Registry<LampView> {
        let registry = Registry<LampView>()

        registry.add(LampContract.self, create: { raise in
            let lamp = LampView()
            lamp.tapped = { index in raise(LampContract.lampTapped, index) }
            return lamp
        }, members: { lamp in
            lamp.property(LampContract.signal) { view, signal in view.signal = signal }
            lamp.property(VisualElementContract.opacity) { view, opacity in view.opacity = opacity }
            lamp.property(LabelContract.maximumLines) { _, _ in }
            lamp.raises(LampContract.lampTapped)
        })

        return registry
    }
}

/// An element a host realizes, declared the way an application declares its
/// own.
private enum LampContract: ElementContract {
    static let nodeType: NodeType = "Test.Lamp"
    static let tiers: [any Contract.Type] = [ViewContract.self]

    static let signal = ElementProperty<Self, Int>("signal")
    static let unrealized = ElementProperty<Self, Bool>("unrealized")
    static let lampTapped = ElementEvent<Self, Int>("lampTapped")

    static let members: [any ContractMember] = [signal, unrealized, lampTapped]
}
