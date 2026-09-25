// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHostConformance
import XCTest

/// The conformance suite on WinUI: every family, each one test, its passing cases proving WinUI's ✅.
final class WinUIConformanceTests: XCTestCase {
    func testToggles() { conform(Toggles.self) }
    func testValues() { conform(Values.self) }
    func testFields() { conform(Fields.self) }
    func testChoices() { conform(Choices.self) }
    func testPresence() { conform(Presence.self) }
    func testWords() { conform(Words.self) }
    func testLayout() { conform(Layout.self) }

    /// Runs `family` on WinUI, and holds what its passing cases proved to the family's file of WinUI's proofs.
    private func conform(_ family: any ConformanceFamily.Type) {
        let proven = onUIThread {
            Conformance.run(
                family, on: WinUIDriver(), report: { XCTFail($0.message, file: $0.file, line: $0.line) },
                log: { print($0) })
        }
        XCTAssertNoThrow(try WinUIExports.hold(Coverage.text(proven), at: "covered/winui/\(family.name).txt"))
    }
}
