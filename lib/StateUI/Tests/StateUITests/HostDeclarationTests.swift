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

    /// A declaration crosses and reads back whole.
    func testADeclarationReadsBackAsItWasWritten() {
        XCTAssertEqual(Wire.decodeDeclaration(Wire.encodeDeclaration(Self.sample)), Self.sample)
    }

    /// The bytes are the same whatever order it was gathered in: sets are
    /// written sorted, the wire's rule.
    func testTheSameDeclarationIsTheSameBytes() {
        let same = HostDeclaration(elements: [
            "Slider": HostDeclaration.Element(
                members: ["value", "minimum", "maximum"], events: ["valueChanged"]),
            "Label": HostDeclaration.Element(members: ["maximumLines", "fontSize"]),
        ])

        XCTAssertEqual(Wire.encodeDeclaration(same), Wire.encodeDeclaration(Self.sample))
    }

    /// A buffer that will not read is refused whole rather than half read.
    func testAnUnreadableBufferIsRefused() {
        XCTAssertNil(Wire.decodeDeclaration([99, 1, 2, 3]))
        XCTAssertNil(Wire.decodeDeclaration(Array(Wire.encodeDeclaration(Self.sample).dropLast())))
        XCTAssertNil(Wire.decodeDeclaration(Wire.encodeDeclaration(Self.sample) + [0]))
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
            Wire.decodeDeclaration([UInt8](try Data(contentsOf: Self.export))),
            "exports/maui.bin did not read. Write it again with STATEUI_UPDATE_EXPORTS=1 "
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

    // MARK: - Support

    /// `exports/maui.bin`, written by the MAUI suite from its registrations.
    private static let export = Fixtures.repository.appendingPathComponent("exports/maui.bin")

    /// A host declaring a label with a member of its own and one of a tier it
    /// wears, and a slider with the value a user moves.
    private static let sample = HostDeclaration(elements: [
        "Label": HostDeclaration.Element(members: ["fontSize", "maximumLines"]),
        "Slider": HostDeclaration.Element(
            members: ["maximum", "minimum", "value"], events: ["valueChanged"]),
    ])
}
