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
                     "Button..clicked: ✅", ": ✅", "Button clicked: ✅", "Button.clicked.twice: ✅"] {
            XCTAssertNil(HostVerdict(line: line), line)
        }
        XCTAssertNil(HostVerdict.read("Button: ✅\nwhat?\n"))
    }

    /// One verdict a subject: a proof outweighs the driver's word that it could not, and that the host realizing
    /// nothing; the text is sorted, so a run writes the same lines every time.
    func testOneVerdictASubjectTheWeightiest() {
        let text = HostVerdict.text([
            HostVerdict(element: "Switch", member: "isOn", mark: .cannot("read isOn of Switch - Hidden.")),
            HostVerdict(element: "Switch", member: "isOn", mark: .proven),
            HostVerdict(element: "Button", member: "icon", mark: .notRealized),
            HostVerdict(element: "Button", member: "icon", mark: .cannot("read icon of Button - Hidden.")),
        ])

        XCTAssertEqual(text, "Button.icon: cannot read icon of Button - Hidden.\nSwitch.isOn: ✅\n")
    }

    /// Met is proven whole or never had; the rest is not met.
    func testMetIsProvenOrNever() {
        let marks: [HostVerdict.Mark] = [.proven, .partial(missing: "m"), .notPlanned(reason: "r"), .notRealized, .cannot("c")]

        XCTAssertEqual(marks.map { HostVerdict(element: "Label", member: "text", mark: $0).meets }, [true, false, true, false, false])
    }
}
