// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// What a host's register says of a member: whether a test of it runs, and what the test's verdict says beside
/// passing - what is missing, or why the host's family never has it.
@MainActor
final class HostRegisterTests: XCTestCase {
    /// A member the runtime realizes is judged whole, so a test of it runs; one realized nowhere runs nothing.
    func testWhatTheRuntimeRealizesRuns() {
        let register = HostRegister(records: []).and([.complete(SwitchContract.isOn)])

        XCTAssertEqual(register.judgement(of: "isOn", on: "Switch", from: nil), .complete)
        XCTAssertTrue(register.realizes("isOn", on: "Switch", from: nil), "a test of it runs")
        XCTAssertNil(register.judgement(of: "value", on: "Stepper", from: nil))
        XCTAssertFalse(register.realizes("value", on: "Stepper", from: nil), "nothing realized, nothing runs")
    }

    /// A written note about a tier's member judges it on every wearer: the runtime naming the member on one element
    /// does not replace the note.
    func testAWrittenNoteOnATierStaysOnAnElementTheRuntimeNames() {
        let register = HostRegister(records: [.partial(VisualElementContract.background, missing: "A colour alone.")])
            .and([.complete(VisualElementContract.background, on: ButtonContract.self)])

        XCTAssertEqual(
            register.judgement(of: "background", on: "Button", from: "VisualElement"), .partial(missing: "A colour alone."))
    }

    /// Never is the register's: a member never had says why, an element never had is never on every member with
    /// its reason, and an element realized none of judges nothing and runs nothing.
    func testNeverComesFromTheRegister() {
        let register = HostRegister(
            records: [.complete(TextualElementContract.text, on: ButtonContract.self), .notPlanned(ImageElementContract.contentMode, on: ButtonContract.self, reason: "No such screen.")],
            unrealized: [MapContract.self], notPlanned: [(MenuBarContract.self, "No bar on a phone.")])

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
            records: [.complete(VisualElementContract.opacity)], byApplication: [MapContract.self])

        XCTAssertEqual(register.judgement(ofElement: "Map"), .byApplication)
        XCTAssertEqual(register.judgement(of: "region", on: "Map", from: nil), .byApplication)
        XCTAssertEqual(register.judgement(of: "opacity", on: "Map", from: "VisualElement"), .byApplication)
        XCTAssertFalse(register.realizes("region", on: "Map", from: nil))
        XCTAssertEqual(register.and([.complete(TextualElementContract.text, on: ButtonContract.self)]).byApplication, [MapContract.nodeType], "kept with the runtime's")
    }

    /// A tier's record reaches every wearer, and each wearer's test is its own.
    func testATiersRecordReachesEveryWearer() {
        let register = HostRegister(records: [.complete(TextualElementContract.text)])

        XCTAssertTrue(register.realizes("text", on: "Text", from: "TextualElement"))
        XCTAssertTrue(register.realizes("text", on: "Button", from: "TextualElement"))
    }

    /// A viewless element - a text span - takes only its own records: no tier's reaches it.
    func testAViewlessElementTakesNoTiersRecord() {
        let register = HostRegister(records: [.complete(VisualElementContract.opacity)])

        XCTAssertFalse(register.realizes("opacity", on: "TextSpan", from: "VisualElement"))
        XCTAssertTrue(register.realizes("opacity", on: "Button", from: "VisualElement"))
    }

    /// An element's unrealized record stands over its tier's: the tier's record still reaches every other wearer, and
    /// the element's member neither runs nor counts as realized.
    func testAnElementsUnrealizedRecordStandsOverItsTiers() {
        let register = HostRegister(records: [
            .complete(AutomationElementContract.accessibilityIdentifier),
            .unrealized(AutomationElementContract.accessibilityIdentifier, on: ToolbarItemContract.self,
                why: "The toolbar item holds none."),
        ])

        XCTAssertEqual(
            register.judgement(of: "accessibilityIdentifier", on: "ToolbarItem", from: "AutomationElement"),
            .unrealized(why: "The toolbar item holds none."))
        XCTAssertFalse(register.realizes("accessibilityIdentifier", on: "ToolbarItem", from: "AutomationElement"))
        XCTAssertTrue(register.realizes("accessibilityIdentifier", on: "Button", from: "AutomationElement"))
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

    /// What a runtime realizes of a backend's element is recorded on the element: each member its registration took,
    /// and each act of its contract the runtime performs - no other element's, and no act it does not perform.
    func testABackendsElementIsRecordedAsItsRegistrationRealizesIt() {
        let realization = HostRealization(elements: ["WebView", "Text"], members: [
            HostRealizedMember(element: "WebView", owner: "WebView", member: "navigated"),
            HostRealizedMember(element: "Text", owner: "TextualElement", member: "text"),
        ])
        let records = HostRegister.records(
            ofBackends: [WebViewContract.self], in: realization, performed: ["goBack", "scrollTo"])

        XCTAssertEqual(records.map { "\($0.owner).\($0.member)" }, ["WebView.goBack", "WebView.navigated"])
    }

    /// What a host wrote by hand is checked against the contracts: a record naming what its owner does not
    /// wear, one written twice, a partial one saying nothing is missing, a never or an unrealized one saying no
    /// reason, and an element both unrealized and never.
    func testTheProblemsOfWhatAHostWroteAreNamed() {
        let register = HostRegister(
            records: [
                .complete(TextualElementContract.text, on: ButtonContract.self), .complete(TextualElementContract.text, on: ButtonContract.self), .complete(SwitchContract.isOn, on: ButtonContract.self),
                .complete(TextualElementContract.textCase), .partial(TextContract.maximumLines, missing: ""),
                .notPlanned(TextContract.lineBreak,
                    reason: ""), .unrealized(TextualElementContract.textCase, on: TextContract.self, why: ""),
            ],
            unrealized: [MapContract.self], notPlanned: [(MapContract.self, "No maps."), (MenuBarContract.self, "")])

        XCTAssertEqual(register.problems, [
            "Button.text is recorded twice",
            "Button.isOn names what no contract of Button declares",
            "Text.maximumLines is partial and says nothing is missing",
            "Text.lineBreak is never and says no reason",
            "Text.textCase is unrealized and says no reason",
            "Map is both unrealized and never",
            "MenuBar is never and says no reason",
        ])
    }

    /// An element left to the application is neither unrealized nor never.
    func testWhatIsLeftToTheApplicationIsNamedOnce() {
        let register = HostRegister(
            records: [], unrealized: [MapContract.self], notPlanned: [(MarkerContract.self, "No pins.")],
            byApplication: [MapContract.self, MarkerContract.self])

        XCTAssertEqual(register.problems, [
            "Marker is both the application's and never",
            "Map is both unrealized and the application's",
        ])
    }
}
