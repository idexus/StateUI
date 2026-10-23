// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the core says about what a host realizes: a node type described for the
// first time that the host does not realize, and an application event a
// handler listens for that the host does not raise - each with the names it
// likely meant, and nothing at all until the host has said what it realizes.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class HostRealizationTests: XCTestCase {
    /// A view type as far as a registry can tell.
    private final class Plain {}

    override func tearDown() async throws {
        HostBoundary.setRealization(HostRealization())
    }

    /// A host that has said nothing is told nothing: every host realizes what
    /// it realizes until it says otherwise.
    func testNothingIsSaidUntilTheHostSaysWhatItRealizes() {
        XCTAssertNil(HostRealizations.unrealized(ButtonContract.nodeType))
        XCTAssertNil(HostRealizations.unraised(owner: KeyName("Test"), event: KeyName("Test.MemoryLow")))
    }

    /// A node type the host realizes goes by without a word.
    func testANodeTypeTheHostRealizesIsNotSaid() {
        HostBoundary.setRealization(Self.realization)

        XCTAssertNil(HostRealizations.unrealized(TextContract.nodeType))
        XCTAssertNil(HostRealizations.unrealized("Test.Lamp"))
    }

    /// A node type it does not realize is said, with the realized names a
    /// misspelling likely meant - and without, where nothing is near.
    func testANodeTypeTheHostDoesNotRealizeIsSaidWithTheNamesItLikelyMeant() {
        HostBoundary.setRealization(Self.realization)

        XCTAssertEqual(
            HostRealizations.unrealized("Test.Lampp"),
            "the host realizes no `Test.Lampp` (nearest: `Test.Lamp`).")
        XCTAssertEqual(HostRealizations.unrealized(ButtonContract.nodeType), "the host realizes no `Button`.")
    }

    /// The differ's placeholder for a composed view never crosses, so no host
    /// realizes it and nothing says so.
    func testTheDiffersPlaceholderIsNeverSaid() {
        HostBoundary.setRealization(Self.realization)

        XCTAssertNil(HostRealizations.unrealized(.composed))
    }

    /// An application event the host raises goes by without a word; one it
    /// does not is said, with the events it raises nearest in name.
    func testAnEventTheHostDoesNotRaiseIsSaidWithTheNamesItLikelyMeant() {
        HostBoundary.setRealization(Self.realization)

        XCTAssertNil(HostRealizations.unraised(owner: KeyName("Test"), event: KeyName("Test.BatteryChanged")))
        XCTAssertEqual(
            HostRealizations.unraised(owner: KeyName("Test"), event: KeyName("Test.BatteryChangd")),
            "the host raises no `Test.BatteryChangd` (nearest: `Test.BatteryChanged`): "
                + "the handler will not hear it.")
    }

    /// A registry records the application's events its host raises, on the
    /// application element - what the core then answers from.
    func testARegistryRecordsTheApplicationsEventsItRaises() {
        let registry = Registry<Plain>()

        registry.raises(TestHostEvents.batteryChanged)
        HostBoundary.setRealization(registry.realization)

        XCTAssertTrue(registry.realization.members.contains(
            HostRealizedMember(element: "Application", owner: "Test", member: "Test.BatteryChanged")))
        XCTAssertTrue(HostBoundary.realizes(TestHostEvents.batteryChanged))
    }

    /// A host says what it realizes, and judges it member by member, at every start - a test's every case on a
    /// phone: what the core answers from is worked out when first asked, once, not at each saying.
    func testAHostSayingItsRegisterAtEveryStartCostsNothingUntilAsked() {
        let records = (0..<2_000).map { HostRecord(owner: "Owner\($0 % 40)", member: "member\($0)", judgment: .complete) }
        let register = HostRegister(records: records)
        let realization = HostRealization(
            elements: ["Text"],
            members: Set(records.map { HostRealizedMember(element: "Text", owner: $0.owner, member: $0.member) }))

        let started = ContinuousClock.now
        for _ in 0..<50 {
            HostBoundary.setRealization(realization)
            HostBoundary.setRegister(register)
        }
        let said = ContinuousClock.now - started

        XCTAssertLessThan(said, .milliseconds(500), "50 starts took \(said)")
        XCTAssertTrue(HostRealizations.honors(KeyName("member7"), of: KeyName("Owner7")))
        XCTAssertFalse(HostRealizations.honors(KeyName("member7"), of: KeyName("Owner8")))
        HostBoundary.setRegister(nil)
    }

    /// A member the host's register says it does not realize on an element, or never will, is said with the
    /// register's reason - on an element the host realizes; one it realizes, in part at least, and one on an
    /// element it does not realize at all, go by without a word.
    func testAMemberTheRegisterSaysTheHostDoesNotRealizeIsSaid() {
        HostBoundary.setRealization(Self.realization)
        HostBoundary.setRegister(HostRegister(records: [
            .unrealized(TintElementContract.tint, on: SliderContract.self, why: "a range input takes no tint"),
            .notPlanned(SliderContract.pressed, reason: "a range input says no press."),
            .partial(SliderContract.value, missing: "steps"),
        ], unrealized: [ButtonContract.self]))
        defer { HostBoundary.setRegister(nil) }

        XCTAssertEqual(
            HostRealizations.unhonored(TintElementContract.tint.token.key, on: SliderContract.nodeType),
            "`Slider.tint` is not realized on this host: a range input takes no tint.")
        XCTAssertEqual(
            HostRealizations.unhonored(SliderContract.pressed.token.key, on: SliderContract.nodeType),
            "`Slider.pressed` is never realized on this host: a range input says no press.")
        XCTAssertNil(HostRealizations.unhonored(SliderContract.value.token.key, on: SliderContract.nodeType))
        XCTAssertNil(HostRealizations.unhonored(SliderContract.maximum.token.key, on: SliderContract.nodeType),
                     "the register says nothing of it")
        XCTAssertNil(HostRealizations.unhonored(TintElementContract.tint.token.key, on: ButtonContract.nodeType),
                     "an element the host does not realize is said once, as an element")
    }

    /// A Slider tinted on a host that does not realize its tint is said once as it is described, however often.
    func testADescribedMemberTheHostDoesNotRealizeIsSaidOnce() {
        HostBoundary.setRealization(Self.realization)
        HostBoundary.setRegister(HostRegister(records: [
            .unrealized(TintElementContract.tint, on: SliderContract.self, why: "a range input takes no tint"),
        ]))
        defer { HostBoundary.setRegister(nil) }
        let value = State(wrappedValue: 0.5)
        let renders = Renders()

        renders.render(Slider(value.projectedValue).tint(.red).node)
        renders.render(Slider(value.projectedValue).tint(.blue).node)

        XCTAssertTrue(hasComplained("`Slider.tint` is not realized on this host"))
    }

    /// What the library writes itself where its author says nothing - a group's position, whether a window floats or
    /// hides - is no description: a host leaving those members unrealized says nothing of them. What the author
    /// says is said.
    func testWhatTheAuthorLeftUnsaidIsNeverSaid() {
        HostBoundary.setRegister(HostRegister(records: [
            .notPlanned(ToolbarGroupContract.position, reason: "the bar has no leading edge."),
            .notPlanned(WindowContract.floatsOnTop, reason: "no window floats."),
            .notPlanned(WindowContract.hidesWhenInactive, reason: "no window hides."),
        ]))
        defer { HostBoundary.setRegister(nil) }
        Renderer.shared.setApplication(UnsaidApp())
        Renderer.shared.clearInvalidation()

        _ = Renderer.shared.renderHost(baseline: 0)

        for member in ["ToolbarGroup.position", "Window.floatsOnTop", "Window.hidesWhenInactive"] {
            XCTAssertFalse(hasComplained("`\(member)`"), "\(member) said, its author having said nothing")
        }

        Renderer.shared.setApplication(LeadingApp())
        _ = Renderer.shared.renderHost(baseline: 0)

        XCTAssertTrue(hasComplained("`ToolbarGroup.position` is never realized"), "a position the author chose is said")
    }

    // MARK: - Support

    /// A host realizing a label and a lamp, and raising one application event.
    private static let realization = HostRealization(
        elements: ["Text", "Test.Lamp"],
        members: [HostRealizedMember(element: "Application", owner: "Test", member: "Test.BatteryChanged")])
}

/// A window whose page has a toolbar, saying nothing of its position or of the window's behavior.
private struct UnsaidApp: Application {
    var body: some Scene { WindowGroup { Text("Parcels").toolbar { ToolbarButton("Reader") } } }
}

/// The same, its toolbar at the leading edge.
private struct LeadingApp: Application {
    var body: some Scene { WindowGroup { Text("Parcels").toolbar { ToolbarButton("Reader").placement(at: .start) } } }
}

/// The application's events these tests name, declared the way an application
/// declares its own.
private enum TestHostEvents: ApplicationTier {
    static let name = "Test"

    static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Test.BatteryChanged")

    static let members: [any ContractMember] = [batteryChanged]
}
