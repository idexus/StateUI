// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A folder's files as another machine's tool reads and writes them through a connection: listed with their size and
/// time, written in pieces - a file made whole only by its last, its time kept - read in pieces, removed. What a
/// machine makes where it builds - `left` - is neither listed nor touched, a link is not followed, and a path never
/// leaves its folder.
/// Design: docs/design/tooling/service.md#files-through-the-connection
enum FolderFiles {
    /// The folders a machine makes for itself where it builds and indexes, which stay as they are on both sides.
    static let left: Set<String> = [
        ".build", ".git", ".gradle", ".projection", ".sourcekit-lsp", ".stateui", ".swiftpm", ".vs", "node_modules",
    ]

    /// The files of `request.root`, none where it stands not.
    static func survey(_ request: FolderSurveyRequest) throws -> FolderSurvey {
        let root = URL(fileURLWithPath: request.root)
        return FolderSurvey(files: try every(under: root).sorted().compactMap { path in
            try? entry(path, in: root)
        })
    }

    /// `path`'s size and time under `root`.
    static func entry(_ path: String, in root: URL) throws -> FileEntry {
        let facts = try place(path, in: root).resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return FileEntry(path: path, size: facts.fileSize ?? 0, modified: facts.contentModificationDate?.timeIntervalSince1970 ?? 0)
    }

    /// Writes `request`'s pieces: a file's first starts it anew beside it, each next one follows where the last ended,
    /// and its last puts it in place with its time.
    static func write(_ request: FilesWriteRequest) throws -> FilesWritten {
        let files = FileManager.default
        let root = URL(fileURLWithPath: request.root)
        var completed = 0
        for piece in request.pieces {
            let target = try place(piece.path, in: root)
            let part = target.appendingPathExtension("stateui-part")
            guard let bytes = Data(base64Encoded: piece.data) else {
                throw ToolingError(.invalidConfiguration, "A piece of \(piece.path) is not base64.")
            }
            if piece.offset == 0 {
                try files.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data().write(to: part)
            }
            let handle = try FileHandle(forWritingTo: part)
            let end = try handle.seekToEnd()
            guard end == UInt64(piece.offset) else {
                try? handle.close()
                throw ToolingError(.invalidConfiguration, "A piece of \(piece.path) at \(piece.offset) follows none: \(end) bytes stand.")
            }
            try handle.write(contentsOf: bytes)
            try handle.close()
            guard piece.offset + bytes.count >= piece.size else { continue }
            if files.fileExists(atPath: target.path) { try files.removeItem(at: target) }
            try files.moveItem(at: part, to: target)
            try files.setAttributes([.modificationDate: Date(timeIntervalSince1970: piece.modified)], ofItemAtPath: target.path)
            completed += 1
        }
        return FilesWritten(completed: completed)
    }

    /// At most `request.length` bytes of a file, from `request.offset`.
    static func read(_ request: FileReadRequest) throws -> FilePiece {
        let root = URL(fileURLWithPath: request.root)
        let entry = try entry(request.path, in: root)
        let handle = try FileHandle(forReadingFrom: try place(request.path, in: root))
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(request.offset))
        let bytes = try handle.read(upToCount: request.length) ?? Data()
        return FilePiece(path: request.path, offset: request.offset, size: entry.size, modified: entry.modified, data: bytes.base64EncodedString())
    }

    /// Removes `request.paths`; the ones gone already are no failure.
    static func remove(_ request: FilesRemoveRequest) throws -> FilesRemoved {
        let root = URL(fileURLWithPath: request.root)
        var removed = 0
        for path in request.paths {
            let target = try place(path, in: root)
            guard FileManager.default.fileExists(atPath: target.path) else { continue }
            try FileManager.default.removeItem(at: target)
            removed += 1
        }
        return FilesRemoved(removed: removed)
    }

    /// Every regular file under `folder`, by its path from it written with `/`, none under what `left` names - walked
    /// folder by folder, as a directory enumerator told to skip a folder skips its siblings too on Windows.
    static func every(under folder: URL) throws -> Set<String> {
        var found: Set<String> = []
        var folders: [(URL, [String])] = [(folder, [])]
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        while let (current, path) = folders.popLast() {
            guard let entries = try? FileManager.default.contentsOfDirectory(at: current, includingPropertiesForKeys: keys) else { continue }
            for entry in entries where !left.contains(entry.lastPathComponent) {
                let facts = try entry.resourceValues(forKeys: Set(keys))
                if facts.isSymbolicLink == true { continue }
                if facts.isDirectory == true {
                    folders.append((entry, path + [entry.lastPathComponent]))
                } else if facts.isRegularFile == true, entry.pathExtension != "stateui-part" {
                    found.insert((path + [entry.lastPathComponent]).joined(separator: "/"))
                }
            }
        }
        return found
    }

    /// `path` under `root` - refused where it names no file of the folder: empty, absolute, or climbing out of it.
    static func place(_ path: String, in root: URL) throws(ToolingError) -> URL {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains(":"),
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw ToolingError(.invalidConfiguration, "\(path) names no file inside its folder.")
        }
        return parts.reduce(root) { $0.appendingPathComponent($1) }
    }
}
