// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A folder made to hold what another holds: a file copied where its size or time differs, one gone from the source
/// removed, the source's time kept on each copy so the next mirror leaves it. What a build makes where it builds -
/// `left` - is neither copied nor removed, and a link is not followed.
/// Design: docs/design/tooling/guests.md#the-copy-in-the-guest
struct FolderMirror: Sendable {
    /// The folders a machine makes for itself where it builds and indexes, which stay as they are on both sides.
    static let left: Set<String> = [
        ".build", ".git", ".gradle", ".projection", ".sourcekit-lsp", ".stateui", ".swiftpm", ".vs", "node_modules",
    ]

    /// Mirrors as `request` says, each step said to `progress`.
    func mirror(_ request: FolderMirrorRequest, progress: @Sendable (String) -> Void = { _ in }) throws -> FolderMirrorResult {
        let files = FileManager.default
        let source = URL(fileURLWithPath: request.sourcePath), target = URL(fileURLWithPath: request.targetPath)
        let wanted = try request.files.map(Set.init) ?? Self.every(under: source)
        progress("mirroring \(wanted.count) files of \(request.sourcePath)")
        var (copied, unchanged) = (0, 0)
        for relative in wanted.sorted() {
            let from = source.appendingPathComponent(relative), to = target.appendingPathComponent(relative)
            guard let facts = try? from.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                  facts.isRegularFile == true else { continue }
            let there = try? to.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            if there?.fileSize == facts.fileSize, let mine = there?.contentModificationDate, let theirs = facts.contentModificationDate,
               abs(mine.timeIntervalSince(theirs)) < 2 {
                unchanged += 1
                continue
            }
            try files.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
            if files.fileExists(atPath: to.path) { try files.removeItem(at: to) }
            try files.copyItem(at: from, to: to)
            if let time = facts.contentModificationDate { try files.setAttributes([.modificationDate: time], ofItemAtPath: to.path) }
            copied += 1
        }
        var removed = 0
        for relative in (try? Self.every(under: target)) ?? [] where !wanted.contains(relative) {
            try files.removeItem(at: target.appendingPathComponent(relative))
            removed += 1
        }
        return FolderMirrorResult(copied: copied, removed: removed, unchanged: unchanged)
    }

    /// Every regular file under `folder`, by its path from it written with `/`, none under what `left` names.
    static func every(under folder: URL) throws -> Set<String> {
        var found: Set<String> = []
        let base = folder.standardizedFileURL.pathComponents.count
        guard let walk = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]) else { return [] }
        for case let entry as URL in walk {
            let facts = try entry.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey])
            if left.contains(entry.lastPathComponent) {
                if facts.isDirectory == true { walk.skipDescendants() }
                continue
            }
            guard facts.isRegularFile == true, facts.isSymbolicLink != true else { continue }
            found.insert(entry.standardizedFileURL.pathComponents.dropFirst(base).joined(separator: "/"))
        }
        return found
    }
}
