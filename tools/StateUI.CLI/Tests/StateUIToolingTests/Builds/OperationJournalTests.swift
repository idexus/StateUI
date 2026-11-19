// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class OperationJournalTests: XCTestCase {
    /// An operation's record is written as it opens - running - and again as it ends, its output beside it.
    func testAnOperationsRecordStaysWithItsOutput() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("journal-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = OperationJournal(root: root)

        let entry = try journal.open(id: "op-1", kind: "build", request: .object(["host": .string("appkit")]))
        XCTAssertEqual(try journal.record(of: "op-1").state, .running)
        entry.write(output: "Compiling Notes\n")
        entry.write(output: "Build complete!\n")
        try entry.finish(.failed, failure: ToolingError(.toolFailed, "the compiler stopped"))

        let record = try journal.record(of: "op-1")
        XCTAssertEqual(record.state, .failed)
        XCTAssertEqual(record.kind, "build")
        XCTAssertEqual(record.failure?.message, "the compiler stopped")
        XCTAssertNotNil(record.finishedAt)
        XCTAssertEqual(record.request, .object(["host": .string("appkit")]))
        let output = try String(contentsOf: journal.folder.appendingPathComponent("op-1/output.log"), encoding: .utf8)
        XCTAssertEqual(output, "Compiling Notes\nBuild complete!\n")
    }

    /// The journal keeps its newest operations and lets the older ones go as another opens - never one running, nor a
    /// folder whose record is not written yet.
    func testTheJournalKeepsItsNewestOperations() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("journal-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = OperationJournal(root: root)
        _ = try journal.open(id: "op-000", kind: "run")
        try FileManager.default.createDirectory(at: journal.folder.appendingPathComponent("op-half"), withIntermediateDirectories: true)
        let opened = OperationJournal.kept + 5
        for number in 1...opened {
            try journal.open(id: String(format: "op-%03d", number), kind: "build").finish(.succeeded)
        }

        let left = try FileManager.default.contentsOfDirectory(atPath: journal.folder.path).sorted()
        let newest = (opened - OperationJournal.kept + 1...opened).map { String(format: "op-%03d", $0) }
        XCTAssertEqual(left, ["op-000"] + newest + ["op-half"])
    }
}
