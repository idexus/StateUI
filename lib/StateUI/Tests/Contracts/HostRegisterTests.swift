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
            records: [.complete("Button", "text"), .notPlanned("Button", "aspect", reason: "No such screen.")],
            unrealized: ["Map"], viewless: [], notPlanned: ["MenuBar": "No bar on a phone."])

        XCTAssertEqual(register.judgement(of: "aspect", on: "Button", from: nil), .notPlanned(reason: "No such screen."))
        XCTAssertEqual(register.judgement(of: "text", on: "MenuBar", from: nil), .notPlanned(reason: "No bar on a phone."))
        XCTAssertEqual(register.judgement(ofElement: "MenuBar"), .notPlanned(reason: "No bar on a phone."))
        XCTAssertNil(register.judgement(of: "text", on: "Map", from: nil))
        XCTAssertNil(register.judgement(ofElement: "Map"))
        XCTAssertEqual(register.judgement(ofElement: "Button"), .complete)
        XCTAssertFalse(register.realizes("text", on: "Map", from: nil))
    }

    /// A tier's record reaches every wearer, and each wearer's test is its own.
    func testATiersRecordReachesEveryWearer() {
        let register = HostRegister(records: [.complete("TextElement", "text")], unrealized: [], viewless: [])

        XCTAssertTrue(register.realizes("text", on: "Label", from: "TextElement"))
        XCTAssertTrue(register.realizes("text", on: "Button", from: "TextElement"))
    }

    /// A viewless element takes only its own records: no tier's reaches it.
    func testAViewlessElementTakesNoTiersRecord() {
        let register = HostRegister(records: [.complete("VisualElement", "opacity")], unrealized: [], viewless: ["Span"])

        XCTAssertFalse(register.realizes("opacity", on: "Span", from: "VisualElement"))
        XCTAssertTrue(register.realizes("opacity", on: "Button", from: "VisualElement"))
    }

    /// A tier's mark promises every wearer: a member a host realizes on only some of its elements wearing the
    /// tier declaring it is recorded on those alone, and one it realizes on all of them on the tier.
    func testAMemberRealizedOnSomeWearersIsRecordedOnThoseAlone() {
        let declaration = HostDeclaration(elements: [
            "Label": HostDeclaration.Element(members: ["text", "textCase"]),
            "TextField": HostDeclaration.Element(members: ["text"]),
        ])
        let records = Set(HostRegister.records(of: declaration).map { "\($0.owner).\($0.member)" })

        XCTAssertTrue(records.contains("TextElement.text"), "\(records.sorted())")
        XCTAssertTrue(records.contains("Label.textCase"), "\(records.sorted())")
        XCTAssertFalse(records.contains("TextElement.textCase"), "\(records.sorted())")
    }

    /// What a host wrote by hand is checked against the contracts: a record naming what its owner does not
    /// declare, one written twice, a partial one saying nothing is missing, a never saying no reason, and an element
    /// both unrealized and never.
    func testTheProblemsOfWhatAHostWroteAreNamed() {
        let register = HostRegister(
            records: [
                .complete("Button", "text"), .complete("Button", "text"), .complete("Button", "wings"),
                .complete("TextElement", "textCase"), .partial("Label", "maximumLines", missing: ""),
                .notPlanned("Label", "lineBreak", reason: ""),
            ],
            unrealized: ["Map"], viewless: [], notPlanned: ["Map": "No maps.", "MenuBar": ""])

        XCTAssertEqual(register.problems, [
            "Button.text is recorded twice",
            "Button.wings names what no contract of Button declares",
            "Label.maximumLines is partial and says nothing is missing",
            "Label.lineBreak is never and says no reason",
            "Map is both unrealized and never",
            "MenuBar is never and says no reason",
        ])
    }
}
