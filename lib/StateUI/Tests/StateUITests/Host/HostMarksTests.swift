// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// The one rule a host's column and a conformance case read: a mark is earned by the host's own passing test,
/// "never" comes from its register, and what it realizes decides only whether a test runs.
final class HostMarksTests: XCTestCase {
    /// A member the host realizes has no mark until a passing test of the host proves it.
    func testAMarkIsEarnedByAPassingTestAlone() {
        let realized = HostMarks(records: [], unrealized: [], viewless: []).and([.complete("Switch", "isOn")])

        XCTAssertTrue(realized.realizes("isOn", on: "Switch", from: nil), "a test of it runs")
        XCTAssertEqual(realized.mark(of: "isOn", on: "Switch", from: nil), .absent, "realized is not proven")
        XCTAssertEqual(realized.proving(["Switch.isOn"]).mark(of: "isOn", on: "Switch", from: nil), .complete)
        XCTAssertFalse(realized.realizes("value", on: "Stepper", from: nil), "nothing realized, nothing runs")
    }

    /// A written note about a tier's member judges it on every wearer: the runtime naming the member on one element
    /// does not replace the note, and the member proven there is ☑️ with what is missing.
    func testAWrittenNoteOnATierStaysOnAnElementTheRuntimeNames() {
        let marks = HostMarks(
            records: [.partial("VisualElement", "background", missing: "A colour alone.")], unrealized: [], viewless: [])
            .and([.complete("Button", "background")])
            .proving(["Button.background"])

        XCTAssertEqual(marks.mark(of: "background", on: "Button", from: "VisualElement"), .partial(missing: "A colour alone."))
    }

    /// – comes from the register alone, proven or not: a member never had says why; an element never had is – on
    /// every member; one realized none of has no mark and runs nothing.
    func testNeverComesFromTheRegister() {
        let marks = HostMarks(
            records: [.complete("Button", "text"), .notPlanned("Button", "aspect", reason: "No such screen.")],
            unrealized: ["Map"], viewless: [], notPlanned: ["MenuBar"])
            .proving(["Button.text", "Button.aspect"])

        XCTAssertEqual(marks.mark(of: "aspect", on: "Button", from: nil), .notPlanned(reason: "No such screen."))
        XCTAssertEqual(marks.mark(of: "text", on: "MenuBar", from: nil), .notPlanned(reason: ""))
        XCTAssertEqual(marks.mark(of: "text", on: "Map", from: nil), .absent)
        XCTAssertFalse(marks.realizes("text", on: "Map", from: nil))
        XCTAssertEqual(marks.mark(of: "text", on: "Button", from: nil), .complete)
    }

    /// A proof is the element's own: a tier's member proven on one wearer marks no other.
    func testAProofMarksItsOwnElementAlone() {
        let marks = HostMarks(records: [.complete("TextElement", "text")], unrealized: [], viewless: [])
            .proving(["Label.text"])

        XCTAssertEqual(marks.mark(of: "text", on: "Label", from: "TextElement"), .complete)
        XCTAssertEqual(marks.mark(of: "text", on: "Button", from: "TextElement"), .absent)
        XCTAssertTrue(marks.realizes("text", on: "Button", from: "TextElement"))
    }

    /// A viewless element takes only its own records: no tier's reaches it.
    func testAViewlessElementTakesNoTiersRecord() {
        let marks = HostMarks(records: [.complete("VisualElement", "opacity")], unrealized: [], viewless: ["Span"])

        XCTAssertFalse(marks.realizes("opacity", on: "Span", from: "VisualElement"))
        XCTAssertTrue(marks.realizes("opacity", on: "Button", from: "VisualElement"))
    }
}
