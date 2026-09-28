// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// A verdict is the one line a host's run writes of a member, and the dictionary's mark is read from it alone.
final class HostVerdictTests: XCTestCase {
    /// Every verdict reads back as it was written, the element itself among them.
    func testAVerdictReadsBackAsItWasWritten() {
        let verdicts = [
            HostVerdict(element: "Button", member: nil, mark: .proven),
            HostVerdict(element: "Button", member: "clicked", mark: .proven),
            HostVerdict(element: "DatePicker", member: "format", mark: .partial(missing: "No pattern: the user's way.")),
            HostVerdict(element: "Map", member: "region", mark: .notPlanned(reason: "No map service: here.")),
            HostVerdict(element: "Line", member: "x1", mark: .notRealized),
            HostVerdict(element: "TextField", member: "submitted", mark: .cannot("submit on TextField - The keyboard's.")),
            HostVerdict(element: "SplitView", member: nil, mark: .waiting(on: "SplitView.isSidebarVisible")),
            HostVerdict(element: "Switch", member: "toggled", mark: .failed("true expected, false came")),
            HostVerdict(element: "Label", member: "text", mark: .partly("cannot read text of Label - Hidden.")),
            HostVerdict(element: "Label", member: "tapped", mark: .byHost("tap on Label: the recognizer is handed it")),
        ]

        for verdict in verdicts {
            XCTAssertEqual(HostVerdict(line: verdict.description), verdict, verdict.description)
        }
        XCTAssertEqual(HostVerdict.read(HostVerdict.text(verdicts))?.sorted { $0.subject < $1.subject },
                       verdicts.sorted { $0.subject < $1.subject })
    }

    /// A line that says no verdict is refused: a mark nobody can read is no mark.
    func testALineThatSaysNoVerdictIsRefused() {
        for line in ["Button.clicked", "Button.clicked: yes", "Button.clicked: ☑️ ", "Button.clicked: – ",
                     "Button..clicked: ✅", ": ✅", "Button clicked: ✅", "Button.clicked.twice: ✅", "Button: waits on ", "Button: ❌ ", "Button: ◐ ", "Button: 🔌 "] {
            XCTAssertNil(HostVerdict(line: line), line)
        }
        XCTAssertNil(HostVerdict.read("Button: ✅\nwhat?\n"))
    }

    /// One verdict a subject, the worst its cases gave: a failure over everything, a proof beside a case that could
    /// not run or read only partly proven, a proof whole only where every case proved it, and the host realizing
    /// nothing below any word of a case; the text is sorted, so a run writes the same lines every time.
    func testOneVerdictASubjectTheWorst() {
        let text = HostVerdict.text([
            HostVerdict(element: "Switch", member: "isOn", mark: .cannot("read isOn of Switch - Hidden.")),
            HostVerdict(element: "Switch", member: "isOn", mark: .proven),
            HostVerdict(element: "Switch", member: "toggled", mark: .proven),
            HostVerdict(element: "Switch", member: "toggled", mark: .failed("true expected, false came")),
            HostVerdict(element: "Switch", member: "toggled", mark: .proven),
            HostVerdict(element: "Button", member: "icon", mark: .notRealized),
            HostVerdict(element: "Button", member: "icon", mark: .cannot("read icon of Button - Hidden.")),
            HostVerdict(element: "Button", member: "text", mark: .proven),
            HostVerdict(element: "Button", member: "text", mark: .partial(missing: "No wrap.")),
            HostVerdict(element: "SplitView", member: nil, mark: .waiting(on: "SplitView.isSidebarVisible")),
            HostVerdict(element: "SplitView", member: nil, mark: .proven),
            HostVerdict(element: "Stepper", member: nil, mark: .notRealized),
            HostVerdict(element: "Stepper", member: nil, mark: .waiting(on: "Stepper.step")),
            HostVerdict(element: "Label", member: nil, mark: .proven),
            HostVerdict(element: "Label", member: nil, mark: .proven),
            HostVerdict(element: "Label", member: "tapped", mark: .byHost("tap on Label: handed")),
            HostVerdict(element: "Label", member: "tapped", mark: .proven),
            HostVerdict(element: "Label", member: "text", mark: .byHost("read text of Label: kept")),
            HostVerdict(element: "Label", member: "text", mark: .byHost("read text of Label: kept")),
            HostVerdict(element: "Label", member: "opacity", mark: .byHost("read opacity of Label: kept")),
            HostVerdict(element: "Label", member: "opacity", mark: .cannot("read opacity of Label - No path.")),
        ])

        XCTAssertEqual(text, """
            Button.icon: cannot read icon of Button - Hidden.
            Button.text: ☑️ No wrap.
            Label: ✅
            Label.opacity: ◐ cannot read opacity of Label - No path.
            Label.tapped: ✅
            Label.text: 🔌 read text of Label: kept
            SplitView: ◐ waits on SplitView.isSidebarVisible
            Stepper: waits on Stepper.step
            Switch.isOn: ◐ cannot read isOn of Switch - Hidden.
            Switch.toggled: ❌ true expected, false came

            """)
    }

    /// A run's text says, over its verdicts, the revision of its family the run was made at; reading it gives both
    /// back, and a text without the line gives no revision.
    func testARunsTextCarriesItsRevision() throws {
        let verdicts = [HostVerdict(element: "Label", member: nil, mark: .proven)]
        let text = HostVerdict.text(verdicts, revision: "2.1")

        XCTAssertEqual(text, "# revision 2.1\nLabel: ✅\n")
        XCTAssertEqual(HostVerdict.read(text), verdicts)
        XCTAssertEqual(HostVerdict.revision(of: text), "2.1")
        XCTAssertEqual(HostVerdict.withoutRevision(text), "Label: ✅\n")
        XCTAssertNil(HostVerdict.revision(of: HostVerdict.text(verdicts)))
        XCTAssertNil(HostVerdict.read("# something else\nLabel: ✅\n"), "a comment other than the revision is no verdict")
    }

    /// A family's revision on a host is its own on every host, then the host's own, each 1 where no line names it;
    /// a verdict file is stale where it names another revision, or none - and a change of the sources is none.
    func testAFamilyStandsAtTheRevisionItsLinesSay() {
        let revisions = """
            # Slider 9 in a comment says nothing
            Slider 2
            winui Slider 3
            appkit Button 4
            """

        XCTAssertEqual(HostVerdict.revision(of: "Slider", on: "winui", in: revisions), "2.3")
        XCTAssertEqual(HostVerdict.revision(of: "Slider", on: "gtk", in: revisions), "2.1")
        XCTAssertEqual(HostVerdict.revision(of: "Button", on: "appkit", in: revisions), "1.4")
        XCTAssertEqual(HostVerdict.revision(of: "Label", on: "winui", in: revisions), "1.1")

        let held = "# revision 2.1\nSlider: ✅\n"
        XCTAssertFalse(HostVerdict.isStale(held, family: "Slider", on: "gtk", in: revisions))
        XCTAssertTrue(HostVerdict.isStale(held, family: "Slider", on: "winui", in: revisions), "WinUI's own was raised")
        XCTAssertTrue(HostVerdict.isStale("Slider: ✅\n", family: "Slider", on: "gtk", in: revisions), "no revision")
        XCTAssertTrue(HostVerdict.isStale(nil, family: "Slider", on: "gtk", in: revisions), "no file")
    }

    /// Met is proven whole or never had; the rest is not met.
    func testMetIsProvenOrNever() {
        let marks: [HostVerdict.Mark] = [
            .proven, .partial(missing: "m"), .notPlanned(reason: "r"), .notRealized, .cannot("c"), .waiting(on: "w"),
            .failed("f"), .partly("p"), .byHost("b"),
        ]

        XCTAssertEqual(
            marks.map { HostVerdict(element: "Label", member: "text", mark: $0).meets },
            [true, false, true, false, false, false, false, false, false])
    }
}
