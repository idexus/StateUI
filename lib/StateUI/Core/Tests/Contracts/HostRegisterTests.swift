// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// What a host's register says of a member: whether a test of it runs, and what the test's verdict says beside
/// passing - what is missing, or why the host's family never has it.
final class HostRegisterTests: XCTestCase {
    /// A member the runtime realizes is judged whole, so a test of it runs; one realized nowhere runs nothing.
    func testWhatTheRuntimeRealizesRuns() {
        let register = HostRegister(records: [], unrealized: [], viewless: []).and([.complete("Switch", "isOn")])

        XCTAssertEqual(register.judgement(of: "isOn", on: "Switch", from: nil), .complete)
        XCTAssertTrue(register.realizes("isOn", on: "Switch", from: nil), "a test of it runs")
        XCTAssertNil(register.judgement(of: "value", on: "Stepper", from: nil))
        XCTAssertFalse(register.realizes("value", on: "Stepper", from: nil), "nothing realized, nothing runs")
    }

    /// A written note about a tier's member judges it on every wearer: the runtime naming the member on one element
    /// does not replace the note.
    func testAWrittenNoteOnATierStaysOnAnElementTheRuntimeNames() {
        let register = HostRegister(
            records: [.partial("VisualElement", "background", missing: "A colour alone.")], unrealized: [], viewless: [])
            .and([.complete("Button", "background")])

        XCTAssertEqual(
            register.judgement(of: "background", on: "Button", from: "VisualElement"), .partial(missing: "A colour alone."))
    }

    /// Never is the register's: a member never had says why, an element never had is never on every member with
    /// its reason, and an element realized none of judges nothing and runs nothing.
    func testNeverComesFromTheRegister() {
        let register = HostRegister(
            records: [.complete("Button", "text"), .notPlanned("Button", "contentMode", reason: "No such screen.")],
            unrealized: ["Map"], viewless: [], notPlanned: ["MenuBar": "No bar on a phone."])

        XCTAssertEqual(register.judgement(of: "contentMode", on: "Button", from: nil), .notPlanned(reason: "No such screen."))
        XCTAssertEqual(register.judgement(of: "text", on: "MenuBar", from: nil), .notPlanned(reason: "No bar on a phone."))
        XCTAssertEqual(register.judgement(ofElement: "MenuBar"), .notPlanned(reason: "No bar on a phone."))
        XCTAssertNil(register.judgement(of: "text", on: "Map", from: nil))
        XCTAssertNil(register.judgement(ofElement: "Map"))
        XCTAssertEqual(register.judgement(ofElement: "Button"), .complete)
        XCTAssertFalse(register.realizes("text", on: "Map", from: nil))
    }

    /// An element left to the application is the application's on itself and on every member, and the host realizes
    /// none of it.
    func testAnElementLeftToTheApplicationIsItsOnEveryMember() {
        let register = HostRegister(
            records: [.complete("VisualElement", "opacity")], unrealized: [], viewless: [], byApplication: ["Map"])

        XCTAssertEqual(register.judgement(ofElement: "Map"), .byApplication)
        XCTAssertEqual(register.judgement(of: "region", on: "Map", from: nil), .byApplication)
        XCTAssertEqual(register.judgement(of: "opacity", on: "Map", from: "VisualElement"), .byApplication)
        XCTAssertFalse(register.realizes("region", on: "Map", from: nil))
        XCTAssertEqual(register.and([.complete("Button", "text")]).byApplication, ["Map"], "kept with the runtime's")
    }

    /// A tier's record reaches every wearer, and each wearer's test is its own.
    func testATiersRecordReachesEveryWearer() {
        let register = HostRegister(records: [.complete("TextualElement", "text")], unrealized: [], viewless: [])

        XCTAssertTrue(register.realizes("text", on: "Text", from: "TextualElement"))
        XCTAssertTrue(register.realizes("text", on: "Button", from: "TextualElement"))
    }

    /// A viewless element takes only its own records: no tier's reaches it.
    func testAViewlessElementTakesNoTiersRecord() {
        let register = HostRegister(records: [.complete("VisualElement", "opacity")], unrealized: [], viewless: ["TextSpan"])

        XCTAssertFalse(register.realizes("opacity", on: "TextSpan", from: "VisualElement"))
        XCTAssertTrue(register.realizes("opacity", on: "Button", from: "VisualElement"))
    }

    /// An element's unrealized record stands over its tier's: the tier's record still reaches every other wearer, and
    /// the element's member neither runs nor counts as realized.
    func testAnElementsUnrealizedRecordStandsOverItsTiers() {
        let register = HostRegister(
            records: [
                .complete("PropertyContainer", "accessibilityIdentifier"),
                .unrealized("ToolbarItem", "accessibilityIdentifier", why: "The toolbar item holds none."),
            ],
            unrealized: [], viewless: [])

        XCTAssertEqual(
            register.judgement(of: "accessibilityIdentifier", on: "ToolbarItem", from: "PropertyContainer"),
            .unrealized(why: "The toolbar item holds none."))
        XCTAssertFalse(register.realizes("accessibilityIdentifier", on: "ToolbarItem", from: "PropertyContainer"))
        XCTAssertTrue(register.realizes("accessibilityIdentifier", on: "Button", from: "PropertyContainer"))
    }

    /// A tier's mark promises every wearer: a member a host realizes on only some of its elements wearing the
    /// tier declaring it is recorded on those alone, and one it realizes on all of them on the tier.
    func testAMemberRealizedOnSomeWearersIsRecordedOnThoseAlone() {
        let declaration = HostDeclaration(elements: [
            "Text": HostDeclaration.Element(members: ["text", "textCase"]),
            "TextField": HostDeclaration.Element(members: ["text"]),
        ])
        let records = Set(HostRegister.records(of: declaration).map { "\($0.owner).\($0.member)" })

        XCTAssertTrue(records.contains("TextualElement.text"), "\(records.sorted())")
        XCTAssertTrue(records.contains("Text.textCase"), "\(records.sorted())")
        XCTAssertFalse(records.contains("TextualElement.textCase"), "\(records.sorted())")
    }

    /// What a host wrote by hand is checked against the contracts: a record naming what its owner does not
    /// declare, one written twice, a partial one saying nothing is missing, a never or an unrealized one saying no
    /// reason, an unrealized one on a tier, and an element both unrealized and never.
    func testTheProblemsOfWhatAHostWroteAreNamed() {
        let register = HostRegister(
            records: [
                .complete("Button", "text"), .complete("Button", "text"), .complete("Button", "wings"),
                .complete("TextualElement", "textCase"), .partial("Text", "maximumLines", missing: ""),
                .notPlanned("Text", "lineBreak", reason: ""), .unrealized("Text", "textCase", why: ""),
                .unrealized("TextualElement", "text", why: "Not here."),
            ],
            unrealized: ["Map"], viewless: [], notPlanned: ["Map": "No maps.", "MenuBar": ""])

        XCTAssertEqual(register.problems, [
            "Button.text is recorded twice",
            "Button.wings names what no contract of Button declares",
            "Text.maximumLines is partial and says nothing is missing",
            "Text.lineBreak is never and says no reason",
            "Text.textCase is unrealized and says no reason",
            "TextualElement.text is unrealized on a tier, which only an element's record says",
            "Map is both unrealized and never",
            "MenuBar is never and says no reason",
        ])
    }

    /// An element left to the application is neither unrealized nor never, and is one the library declares.
    func testWhatIsLeftToTheApplicationIsNamedOnce() {
        let register = HostRegister(
            records: [], unrealized: ["Map"], viewless: [], notPlanned: ["Marker": "No pins."],
            byApplication: ["Map", "Marker", "Globe"])

        XCTAssertEqual(register.problems, [
            "Marker is both the application's and never",
            "Globe is left to the application, and the library declares no such element",
            "Map is both unrealized and the application's",
        ])
    }
}
