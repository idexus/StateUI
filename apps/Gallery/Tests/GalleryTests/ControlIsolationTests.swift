// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

@MainActor
final class ControlIsolationTests: XCTestCase {
    func testMountedControlOperationsRequireTheUIActor() throws {
        let operations = [
            """
            func callback(_ values: ControlValues<TextContract>) {
                _ = values[TextElementContract.text]
            }
            """,
            """
            func callback(_ reports: ControlReports<ButtonContract>) {
                reports.raise(ClickElementContract.clicked)
            }
            """,
            """
            func callback(_ reports: ControlReports<SwitchContract>) {
                reports.report(ToggleElementContract.isOn, true, as: ToggleElementContract.toggled)
            }
            """,
            """
            func callback(_ child: ControlChild<MarkerContract>) {
                _ = child.value(MarkerContract.title)
            }
            """,
            """
            func callback(_ child: ControlChild<MarkerContract>) {
                child.reports.raise(MarkerContract.selected)
            }
            """,
        ]

        for (index, operation) in operations.enumerated() {
            XCTAssertNotNil(try compile(operation, name: "outside_\(index)"))
            XCTAssertNil(try compile("@MainActor\n" + operation, name: "ui_\(index)"))
        }
    }

    func testControlMetadataDoesNotReadNativeState() throws {
        XCTAssertNil(try compile("""
            func same(_ left: ControlChild<MarkerContract>, _ right: ControlChild<MarkerContract>) -> Bool {
                Set([left]).contains(right)
            }
            func changed(_ values: ControlValues<TextContract>) -> Bool {
                values.changed(TextElementContract.text)
            }
            """, name: "identity"))
    }

    func testPurposeControlsRequireTheirPurposeValues() throws {
        for (index, control) in ["Picker()", "Link()"].enumerated() {
            XCTAssertNotNil(try compile("@MainActor func view() { _ = \(control) }", name: "purpose_\(index)"))
        }
        XCTAssertNil(try compile("""
            @MainActor func views() {
                let selection = State(wrappedValue: 1)
                _ = Picker([1, 2], selection: selection.projectedValue)
                _ = Link("StateUI", address: "https://stateui.dev")
                _ = Style<Picker>()
                _ = Style<Link>()
            }
            """, name: "purpose_values"))
    }

    private func compile(_ source: String, name: String) throws -> String? {
        let module = try XCTUnwrap(DocumentationExamplesTests.builtModuleDirectory())
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-controls-\(UUID())")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let file = scratch.appendingPathComponent(name + ".swift")
        try Data(("import StateUI\n" + source).utf8).write(to: file)
        return DocumentationExamplesTests.compile(
            file, module: module, sdk: try DocumentationExamplesTests.sdkPath(), warningsAsErrors: true)
    }
}
