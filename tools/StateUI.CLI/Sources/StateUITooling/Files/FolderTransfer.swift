// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A folder carried between this machine and another's tool over one connection: the files whose size or time
/// differs sent - or fetched - in pieces of at most 4 MiB a message, the time kept, what the other side holds
/// beyond them removed.
/// Design: docs/design/tooling/service.md#files-through-the-connection
enum FolderTransfer {
    /// The bytes one message carries at most.
    static let limit = 4 << 20

    /// What a transfer did.
    struct Counts: Equatable, Sendable {
        var carried = 0
        var removed = 0
        var unchanged = 0
    }

    /// Sends `files` of `root` - every file but what a build makes where it is nil - to `remote`, a folder of the
    /// session's machine.
    static func send(
        _ root: URL, files: [String]?, to remote: String, over session: ServedTool.Session, progress: @Sendable (String) -> Void
    ) async throws -> Counts {
        let local = try (files.map(Set.init) ?? FolderFiles.every(under: root)).sorted().compactMap { try FolderFiles.listed($0, in: root) }
        let there = try await session.query("folder/survey", try JSONValue(encoding: FolderSurveyRequest(root: remote)))
            .decode(FolderSurvey.self).files
        let (changed, extra, counts) = differences(local, there)
        progress("sending \(changed.count) of \(local.count) files to \(remote)")
        var pieces: [FilePiece] = []
        var size = 0
        func flush() async throws {
            guard !pieces.isEmpty else { return }
            _ = try await session.query("files/write", try JSONValue(encoding: FilesWriteRequest(root: remote, pieces: pieces)))
            (pieces, size) = ([], 0)
        }
        for entry in changed {
            let data = try Data(contentsOf: try FolderFiles.place(entry.path, in: root))
            var offset = 0
            repeat {
                let piece = data.subdata(in: offset..<min(data.count, offset + limit))
                if size + piece.count > limit { try await flush() }
                pieces.append(FilePiece(
                    path: entry.path, offset: offset, size: data.count, modified: entry.modified, executable: entry.executable,
                    data: piece.base64EncodedString()))
                (size, offset) = (size + piece.count, offset + piece.count)
            } while offset < data.count
        }
        try await flush()
        if !extra.isEmpty {
            _ = try await session.query("files/remove", try JSONValue(encoding: FilesRemoveRequest(root: remote, paths: extra)))
        }
        return counts
    }

    /// Fetches the files of `remote`, a folder of the session's machine, into `root` - `files` alone where named, what
    /// stands beside them on either side left as it is.
    static func fetch(
        _ remote: String, files: [String]? = nil, into root: URL, over session: ServedTool.Session,
        progress: @Sendable (String) -> Void
    ) async throws -> Counts {
        let named = files.map(Set.init)
        let there = try await session.query("folder/survey", try JSONValue(encoding: FolderSurveyRequest(root: remote)))
            .decode(FolderSurvey.self).files.filter { named?.contains($0.path) ?? true }
        let local = try (named ?? FolderFiles.every(under: root)).sorted().compactMap { try FolderFiles.listed($0, in: root) }
        let (changed, extra, counts) = differences(there, local)
        progress("fetching \(changed.count) of \(there.count) files from \(remote)")
        for entry in changed {
            var offset = 0
            repeat {
                let piece = try await session.query("file/read", try JSONValue(encoding: FileReadRequest(
                    root: remote, path: entry.path, offset: offset, length: limit))).decode(FilePiece.self)
                _ = try FolderFiles.write(FilesWriteRequest(root: root.path, pieces: [piece]))
                offset += Data(base64Encoded: piece.data)?.count ?? 0
                if piece.data.isEmpty { break }
            } while offset < entry.size
        }
        _ = try FolderFiles.remove(FilesRemoveRequest(root: root.path, paths: extra))
        return counts
    }

    /// The files of `source` the `target` lacks or holds otherwise - by size, a time apart by a millisecond or more, or
    /// whether it is a program where both systems say - and the paths `target` holds beyond `source`.
    /// Design: docs/design/tooling/service.md#files-through-the-connection
    static func differences(_ source: [FileEntry], _ target: [FileEntry]) -> (changed: [FileEntry], extra: [String], counts: Counts) {
        let held = Dictionary(target.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        let changed = source.filter { entry in
            guard let other = held[entry.path] else { return true }
            let mode = entry.executable.flatMap { mine in other.executable.map { mine != $0 } } ?? false
            return other.size != entry.size || abs(other.modified - entry.modified) >= 0.001 || mode
        }
        let wanted = Set(source.map(\.path))
        let extra = target.map(\.path).filter { !wanted.contains($0) }.sorted()
        return (changed, extra, Counts(carried: changed.count, removed: extra.count, unchanged: source.count - changed.count))
    }
}
