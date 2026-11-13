// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import Synchronization

/// The durable record of a project's operations: `<root>/.stateui/operations/<id>/`, its `operation.json` - what was
/// asked, its state, when - and its `output.log`, what its programs said. A connection's operations live in memory;
/// this is what stays once it is gone.
/// Design: docs/design/tooling/builds.md#the-operation-journal
public struct OperationJournal: Sendable {
    /// The project root the journal stands in: a workspace's folder, else the application's.
    public let root: URL

    /// The journal of the project at `root`.
    public init(root: URL) {
        self.root = root
    }

    /// The folder of the operations' records.
    public var folder: URL {
        root.appendingPathComponent(".stateui").appendingPathComponent("operations")
    }

    /// Opens the record of operation `id` of `kind`, asked as `request`, running.
    public func open(id: String, kind: String, request: JSONValue? = nil) throws -> Entry {
        let entry = folder.appendingPathComponent(id)
        try FileManager.default.createDirectory(at: entry, withIntermediateDirectories: true)
        let record = OperationRecord(
            schemaVersion: OperationRecord.currentVersion, id: id, kind: kind, state: .running,
            createdAt: Operations.timestamp(), request: request)
        try record.write(to: entry)
        let output = entry.appendingPathComponent("output.log")
        guard FileManager.default.createFile(atPath: output.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: output.path])
        }
        return Entry(folder: entry, record: record)
    }

    /// The record of operation `id`, as it was last written.
    public func record(of id: String) throws -> OperationRecord {
        try ToolingJSON.decoder().decode(
            OperationRecord.self, from: Data(contentsOf: folder.appendingPathComponent(id).appendingPathComponent("operation.json")))
    }

    /// One operation's record, open while it runs.
    public final class Entry: Sendable {
        private let folder: URL
        private let record: Mutex<OperationRecord>

        fileprivate init(folder: URL, record: OperationRecord) {
            self.folder = folder
            self.record = Mutex(record)
        }

        /// Appends what a program said to the operation's output.
        public func write(output text: String) {
            guard let handle = try? FileHandle(forWritingTo: folder.appendingPathComponent("output.log")) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(text.utf8))
        }

        /// Writes the state the operation ended in, and the failure where it failed.
        public func finish(_ state: OperationState, failure: ToolingError? = nil) throws {
            let record = record.withLock { record in
                record.state = state
                record.finishedAt = Operations.timestamp()
                record.failure = failure
                return record
            }
            try record.write(to: folder)
        }
    }
}

/// `operation.json`: one operation as the journal keeps it.
public struct OperationRecord: Codable, Equatable, Sendable {
    /// The version of this file's schema.
    public static let currentVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var kind: String
    public var state: OperationState
    public var createdAt: String
    public var finishedAt: String?
    public var request: JSONValue?
    public var failure: ToolingError?

    fileprivate func write(to folder: URL) throws {
        let file = folder.appendingPathComponent("operation.json")
        let staged = folder.appendingPathComponent(".operation.json.new")
        try (ToolingJSON.encoder(pretty: true).encode(self) + Data("\n".utf8)).write(to: staged)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        try FileManager.default.moveItem(at: staged, to: file)
    }
}
