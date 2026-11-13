// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if !os(Windows)
import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

/// A host's suite with a stand-in for SwiftPM that writes what it was asked, and refuses the API record of the
/// facade.
final class HostSuiteTests: XCTestCase {
    /// The suite's tests, then each API record, are phases of their own; one differing fails the suite alone; what
    /// would record anything never reaches it; and the machine's permit is let go.
    func testEachPhaseStandsApartAndNothingIsRecorded() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("suite-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let asked = root.appendingPathComponent("asked")
        let swift = root.appendingPathComponent("swift")
        let script = """
            #!/bin/sh
            echo "$* update=${STATEUI_UPDATE_EXPORTS:-none} module=${STATEUI_API_MODULE:-none}" >> '\(asked.path)'
            case "$*" in *--show-bin-path*) echo '\(root.path)/bin' ;; esac
            [ "$STATEUI_API_MODULE" = StateUIAppKit ] && exit 1
            exit 0
            """
        try script.write(to: swift, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: swift.path)
        let permit = BuildPermit(folder: root.appendingPathComponent("state"))
        setenv("STATEUI_UPDATE_EXPORTS", "1", 1)
        defer { unsetenv("STATEUI_UPDATE_EXPORTS") }

        let result = try await HostSuite(checkout: root, environment: ["SWIFT_BIN": swift.path], permit: permit).run(.appkit)

        XCTAssertEqual(result.phases.map(\.name), ["tests", "api StateUIAppKit", "api StateUITesting"])
        XCTAssertEqual(result.phases.map(\.passed), [true, false, true])
        XCTAssertFalse(result.passed)
        let lines = try String(contentsOf: asked, encoding: .utf8).split(separator: "\n")
        XCTAssertTrue(lines.allSatisfy { $0.contains("update=none") }, lines.joined(separator: "\n"))
        XCTAssertTrue(lines.first?.hasPrefix("test --package-path \(root.path)/lib/StateUI/StateUI.AppKit") == true)
        XCTAssertNil(permit.holder)
    }
}
#endif
