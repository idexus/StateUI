// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the core says about what a host realizes: a node type described for the
// first time that the host does not realize, and an application event a
// handler listens for that the host does not raise - each with the names it
// likely meant, and nothing at all until the host has said what it realizes.

import XCTest
@_spi(Host) @testable import StateUI

final class HostRealizationTests: XCTestCase {
    /// A view type as far as a registry can tell.
    private final class Plain {}

    override func tearDown() {
        StateUIHost.setRealization(HostRealization())
        super.tearDown()
    }

    /// A host that has said nothing is told nothing: every host realizes what
    /// it realizes until it says otherwise.
    func testNothingIsSaidUntilTheHostSaysWhatItRealizes() {
        XCTAssertNil(HostRealizations.unrealized(ButtonContract.nodeType))
        XCTAssertNil(HostRealizations.unraised(owner: "Test", event: "Test.MemoryLow"))
    }

    /// A node type the host realizes goes by without a word.
    func testANodeTypeTheHostRealizesIsNotSaid() {
        StateUIHost.setRealization(Self.realization)

        XCTAssertNil(HostRealizations.unrealized(LabelContract.nodeType))
        XCTAssertNil(HostRealizations.unrealized("Test.Lamp"))
    }

    /// A node type it does not realize is said, with the realized names a
    /// misspelling likely meant - and without, where nothing is near.
    func testANodeTypeTheHostDoesNotRealizeIsSaidWithTheNamesItLikelyMeant() {
        StateUIHost.setRealization(Self.realization)

        XCTAssertEqual(
            HostRealizations.unrealized("Test.Lampp"),
            "the host realizes no `Test.Lampp` (nearest: `Test.Lamp`).")
        XCTAssertEqual(HostRealizations.unrealized(ButtonContract.nodeType), "the host realizes no `Button`.")
    }

    /// The differ's placeholder for a composed view never crosses, so no host
    /// realizes it and nothing says so.
    func testTheDiffersPlaceholderIsNeverSaid() {
        StateUIHost.setRealization(Self.realization)

        XCTAssertNil(HostRealizations.unrealized(.composed))
    }

    /// An application event the host raises goes by without a word; one it
    /// does not is said, with the events it raises nearest in name.
    func testAnEventTheHostDoesNotRaiseIsSaidWithTheNamesItLikelyMeant() {
        StateUIHost.setRealization(Self.realization)

        XCTAssertNil(HostRealizations.unraised(owner: "Test", event: "Test.BatteryChanged"))
        XCTAssertEqual(
            HostRealizations.unraised(owner: "Test", event: "Test.BatteryChangd"),
            "the host raises no `Test.BatteryChangd` (nearest: `Test.BatteryChanged`): "
                + "the handler will not hear it.")
    }

    /// A registry records the application's events its host raises, on the
    /// application element - what the core then answers from.
    func testARegistryRecordsTheApplicationsEventsItRaises() {
        let registry = Registry<Plain>()

        registry.raises(TestHostEvents.batteryChanged)
        StateUIHost.setRealization(registry.realization)

        XCTAssertTrue(registry.realization.members.contains(
            HostRealizedMember(element: "Application", owner: "Test", member: "Test.BatteryChanged")))
        XCTAssertTrue(StateUIHost.realizes(TestHostEvents.batteryChanged))
    }

    // MARK: - Support

    /// A host realizing a label and a lamp, and raising one application event.
    private static let realization = HostRealization(
        elements: ["Label", "Test.Lamp"],
        members: [HostRealizedMember(element: "Application", owner: "Test", member: "Test.BatteryChanged")])
}

/// The application's events these tests name, declared the way an application
/// declares its own.
private enum TestHostEvents: ApplicationTier {
    static let name = "Test"

    static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Test.BatteryChanged")

    static let members: [any ContractMember] = [batteryChanged]
}
