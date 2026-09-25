// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// The one rule a host's column and a conformance case read: what a host realizes of a member.
final class HostMarksTests: XCTestCase {
    /// A written note about a tier's member judges it on every wearer: the runtime naming the member on one
    /// element does not replace the note with a bare mark.
    func testAWrittenNoteOnATierStaysOnAnElementTheRuntimeNames() {
        let written = HostMarks(
            records: [.partial("VisualElement", "background", missing: "A colour alone.")], unrealized: [], viewless: [])
        let marks = written.and([.complete("Button", "background")])

        XCTAssertEqual(marks.mark(of: "background", on: "Button", from: "VisualElement"), .partial(missing: "A colour alone."))
    }

    /// – meets the contract: a member not planned is marked so, with why; an element not planned is – on every
    /// member; one realized none of has no mark.
    func testNotPlannedMeetsTheContract() {
        let marks = HostMarks(
            records: [.complete("Button", "text"), .notPlanned("Button", "aspect", reason: "No such screen.")],
            unrealized: ["Map"], viewless: [], notPlanned: ["MenuBar"])

        XCTAssertEqual(marks.mark(of: "aspect", on: "Button", from: nil), .notPlanned(reason: "No such screen."))
        XCTAssertEqual(marks.mark(of: "text", on: "MenuBar", from: nil), .notPlanned(reason: ""))
        XCTAssertEqual(marks.mark(of: "text", on: "Map", from: nil), .absent)
        XCTAssertEqual(marks.mark(of: "text", on: "Button", from: nil), .complete)
    }

    /// A viewless element takes only its own records: no tier's reaches it.
    func testAViewlessElementTakesNoTiersRecord() {
        let marks = HostMarks(records: [.complete("VisualElement", "opacity")], unrealized: [], viewless: ["Span"])

        XCTAssertEqual(marks.mark(of: "opacity", on: "Span", from: "VisualElement"), .absent)
        XCTAssertEqual(marks.mark(of: "opacity", on: "Button", from: "VisualElement"), .complete)
    }
}
