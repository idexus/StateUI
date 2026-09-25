// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHostConformance
import XCTest

/// The conformance suite on GTK: every family, each one test.
final class GTKConformanceTests: XCTestCase {
    func testToggles() { conform(Toggles.self) }
    func testValues() { conform(Values.self) }
    func testFields() { conform(Fields.self) }
    func testChoices() { conform(Choices.self) }

    private func conform(_ family: any ConformanceFamily.Type) {
        onUIThread {
            Conformance.run(
                family, on: GTKDriver(), report: { XCTFail($0.message, file: $0.file, line: $0.line) },
                log: { print($0) })
        }
    }
}
