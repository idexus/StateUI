// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a host declares about itself, read off its runtime and written to
// exports/, and what that declaration MEANS against the contracts.
//
// The division is the point: a runtime knows which members it realizes and a
// contract knows who declares them, so neither states the other's half. The
// join is here, and an owner it works out is an owner nobody typed.

import XCTest
@_spi(Host) @testable import StateUI

final class HostDeclarationTests: XCTestCase {

    /// A declaration written as text reads back whole, shared machinery and
    /// acts included.
    func testADeclarationReadsBackAsItWasWritten() {
        var sample = Self.sample
        sample.shared = HostDeclaration.Element(members: ["opacity"], events: ["tapped"])
        sample.acts = ["focus"]

        XCTAssertEqual(HostDeclaration(sidecar: sample.sidecar), sample)
    }

    /// The text is the same whatever order it was gathered in: the sets are
    /// written sorted.
    func testTheSameDeclarationIsTheSameText() {
        let same = HostDeclaration(elements: [
            "Slider": HostDeclaration.Element(
                members: ["value", "minimum", "maximum"], events: ["valueChanged"]),
            "Label": HostDeclaration.Element(members: ["maximumLines", "fontSize"]),
        ])

        XCTAssertEqual(same.sidecar, Self.sample.sidecar)
    }

    /// A text that is not a declaration is refused whole rather than half read.
    func testATextThatIsNotADeclarationIsRefused() {
        let whole = Self.sample.sidecar

        XCTAssertNotNil(HostDeclaration(sidecar: whole))
        XCTAssertNil(HostDeclaration(sidecar: ""), "no shared machinery and no acts")
        XCTAssertNil(
            HostDeclaration(sidecar: whole.replacingOccurrences(of: "(acts)\n", with: "")),
            "the acts left out")
        XCTAssertNil(HostDeclaration(sidecar: "  opacity\n" + whole), "a member under nothing")
        XCTAssertNil(HostDeclaration(sidecar: "Label\n" + whole), "an element said twice")
        XCTAssertNil(HostDeclaration(sidecar: whole + "Label\n"), "an element after the shared machinery")
        XCTAssertNil(HostDeclaration(sidecar: whole + "  opacity\n"), "a member among the acts")
    }

    /// THE JOIN: a member is named under the contract DECLARING it - the
    /// element's own where the element declares it, and the tier's where a
    /// tier does. This is what a host cannot say and what nobody now types.
    func testAMembersOwnerComesFromTheContractAndNotFromTheHost() {
        let realization = Self.sample.realization

        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Label", owner: "Label", member: "maximumLines")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Label", owner: "FontElement", member: "fontSize")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Slider", owner: "Slider", member: "valueChanged")))
    }

    /// The elements it declares are the elements it realizes, and the core
    /// answers from them.
    func testTheJoinedRealizationIsWhatTheCoreAnswersFrom() {
        StateUIHost.setRealization(Self.sample.realization)
        defer { StateUIHost.setRealization(HostRealization()) }

        XCTAssertTrue(StateUIHost.realizes(LabelContract.self))
        XCTAssertTrue(StateUIHost.realizes(LabelContract.maximumLines))
        XCTAssertTrue(StateUIHost.realizes(FontElementContract.fontSize))
        XCTAssertFalse(StateUIHost.realizes(ButtonContract.self))
    }

    /// A member no contract declares is NOT quietly given the element as its
    /// owner: it is a host and the contracts disagreeing, and it is named.
    func testAMemberNoContractDeclaresIsNamedRatherThanGuessedAt() {
        let wrong = HostDeclaration(elements: [
            "Label": HostDeclaration.Element(members: ["maximumLines", "nosuchmember"]),
        ])

        XCTAssertFalse(wrong.realization.members.contains { $0.member == "nosuchmember" })
        XCTAssertEqual(wrong.undeclared.map(\.member), ["nosuchmember"])
    }

    /// THE EXPORT ITSELF: what the MAUI runtime wrote is read here, joined
    /// with the contracts, and every name in it is one the contracts know.
    ///
    /// This is the guard that replaces reading a hand-written declaration: the
    /// runtime says what it realizes, and a name it invents fails HERE rather
    /// than becoming a row nobody can explain.
    func testTheMauiExportJoinsWithTheContracts() throws {
        let declaration = try XCTUnwrap(
            HostDeclaration(sidecar: try String(contentsOf: Self.export, encoding: .utf8)),
            "exports/maui.txt did not read. Write it again with STATEUI_UPDATE_EXPORTS=1 "
            + "dotnet test lib/StateUI.Maui/Tests.")

        XCTAssertTrue(
            declaration.undeclared.isEmpty,
            "The MAUI export names what no contract declares: "
            + declaration.undeclared.map { "\($0.element).\($0.member)" }.joined(separator: ", "))

        let realization = declaration.realization

        XCTAssertTrue(realization.elements.contains("Slider"))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Slider", owner: "Slider", member: "valueChanged")))

        // The drift this road exists to end: `aspect` reaches an Image through
        // the tier declaring it, whatever the host called the member.
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Image", owner: "ImageElement", member: "aspect")))
    }

    /// A registry's realization says each member on every element; its declaration says an element's
    /// own there, the shared machinery once, and leaves an application's own element to the application.
    func testARegistryDeclaresTheSharedMachineryOnce() {
        let realization = HostRealization(
            elements: ["Label", "Slider", "Doodle"],
            members: [
                HostRealizedMember(element: "Label", owner: "Label", member: "maximumLines"),
                HostRealizedMember(element: "Label", owner: "VisualElement", member: "opacity"),
                HostRealizedMember(element: "Slider", owner: "Slider", member: "valueChanged"),
                HostRealizedMember(element: "Slider", owner: "VisualElement", member: "opacity"),
                HostRealizedMember(element: "Slider", owner: "View", member: "tapped"),
                HostRealizedMember(element: "Doodle", owner: "Doodle", member: "ink"),
            ])

        let declaration = HostDeclaration(realization: realization, shared: ["opacity", "tapped"], acts: ["focus"])

        XCTAssertEqual(declaration.elements, [
            "Label": HostDeclaration.Element(members: ["maximumLines"]),
            "Slider": HostDeclaration.Element(events: ["valueChanged"]),
        ])
        XCTAssertEqual(declaration.shared, HostDeclaration.Element(members: ["opacity"], events: ["tapped"]))
        XCTAssertEqual(declaration.acts, ["focus"])
        XCTAssertEqual(declaration.sidecar, """
            Label
              maximumLines
            Slider
              valueChanged()
            (every element)
              opacity
              tapped()
            (acts)
              focus()

            """)
    }

    // MARK: - Support

    /// `exports/maui.txt`, written by the MAUI suite from its registrations.
    private static let export = Fixtures.repository.appendingPathComponent("exports/maui.txt")

    /// A host declaring a label with a member of its own and one of a tier it
    /// wears, and a slider with the value a user moves.
    private static let sample = HostDeclaration(elements: [
        "Label": HostDeclaration.Element(members: ["fontSize", "maximumLines"]),
        "Slider": HostDeclaration.Element(
            members: ["maximum", "minimum", "value"], events: ["valueChanged"]),
    ])
}
