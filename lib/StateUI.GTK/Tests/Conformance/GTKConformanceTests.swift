// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHostConformance
import XCTest

/// The conformance suite on GTK: every family, each one test, its passing cases proving GTK's ✅.
final class GTKConformanceTests: XCTestCase {
    func testToggles() { conform(Toggles.self) }
    func testValues() { conform(Values.self) }
    func testFields() { conform(Fields.self) }
    func testChoices() { conform(Choices.self) }
    func testPresence() { conform(Presence.self) }
    func testWords() { conform(Words.self) }
    func testLayout() { conform(Layout.self) }

    /// Runs `family` on GTK, and holds what its passing cases proved to the family's file of GTK's proofs.
    private func conform(_ family: any ConformanceFamily.Type) {
        let proven = onUIThread {
            Conformance.run(
                family, on: GTKDriver(), report: { XCTFail($0.message, file: $0.file, line: $0.line) },
                log: { print($0) })
        }
        XCTAssertNoThrow(try GTKExports.hold(Coverage.text(proven), at: "covered/gtk/\(family.name).txt"))
    }
}
