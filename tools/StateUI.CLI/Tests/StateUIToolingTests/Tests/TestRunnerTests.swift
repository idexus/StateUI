// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if !os(Windows)
import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

/// A package's suite run with a stand-in for SwiftPM that writes what it was asked.
final class TestRunnerTests: XCTestCase {
    private func run(_ suite: TestSuiteDescription, says: String, filter: String? = nil) async throws -> (passed: Bool, asked: String) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("runner-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let asked = root.appendingPathComponent("asked")
        let swift = root.appendingPathComponent("swift")
        try "#!/bin/sh\necho \"$*\" >> '\(asked.path)'\necho '\(says)'\n"
            .write(to: swift, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: swift.path)
        let ran = try await TestRunner(tools: ToolResolver(environment: ["SWIFT_BIN": swift.path]))
            .run(suite, device: nil, filter: filter, checkout: nil, reporter: BuildReporter())
        return (ran.passed, try String(contentsOf: asked, encoding: .utf8))
    }

    /// An application built as an AppKit head enables its trait, in a scratch folder of its own; every other package
    /// runs as plain Swift.
    func testAnAppKitBuildEnablesItsTraitAndKeepsItsOwnFolder() async throws {
        let package = URL(fileURLWithPath: "/Projects/Notes")
        let appKit = try await run(TestSuiteDescription(
            id: "Notes", detail: "", kind: .package, packageUri: FileURI.string(package), host: .appkit), says: "Executed 1 test")
        XCTAssertTrue(appKit.passed)
        XCTAssertEqual(appKit.asked, "test --package-path /Projects/Notes --traits AppKit --scratch-path /Projects/Notes/.build/appkit\n")

        let plain = try await run(TestSuiteDescription(
            id: "Notes", detail: "", kind: .package, packageUri: FileURI.string(package)), says: "Executed 1 test")
        XCTAssertEqual(plain.asked, "test --package-path /Projects/Notes\n")
    }

    /// A run `filter`ed runs only the tests the filter matches.
    func testAFilteredRunAsksForItsTestsAlone() async throws {
        let filtered = try await run(TestSuiteDescription(
            id: "Notes", detail: "", kind: .package, packageUri: "file:///Projects/Notes"), says: "Executed 1 test", filter: "NotesTests")
        XCTAssertEqual(filtered.asked, "test --package-path /Projects/Notes --filter NotesTests\n")
    }

    /// A run that ran no test proves nothing, and fails.
    func testARunOfNoTestFails() async throws {
        let ran = try await run(TestSuiteDescription(
            id: "Notes", detail: "", kind: .package, packageUri: "file:///Projects/Notes"), says: "Executed 0 tests")
        XCTAssertFalse(ran.passed)
    }
}
#endif
