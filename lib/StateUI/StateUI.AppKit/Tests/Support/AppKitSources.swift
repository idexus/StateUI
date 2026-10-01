// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation

/// The host's sources as text, for the guards that hold its architecture: one
/// element doing its one thing, and no other file doing it.
enum AppKitSources {
    /// Every Swift source under `Sources/`, by its file name, sorted - the walk
    /// recursing as the build's own glob does, so a file moved into a folder
    /// is still read. A walk that read almost nothing is refused: every guard
    /// reading it would pass on nothing.
    static func all() throws -> [(name: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Support
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI.AppKit
            .appendingPathComponent("Sources")
        var found: [(name: String, text: String)] = []

        guard let walk = FileManager.default.enumerator(atPath: root.path) else {
            throw WalkReadAlmostNothing(root: root.path, read: 0)
        }

        for case let path as String in walk where path.hasSuffix(".swift") {
            let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            found.append((name: URL(fileURLWithPath: path).lastPathComponent, text: text))
        }

        guard found.count > 25 else { throw WalkReadAlmostNothing(root: root.path, read: found.count) }

        return found.sorted { $0.name < $1.name }
    }

    /// Every Swift source of this suite, by its file name, sorted - read the
    /// same way, and refused the same way when it reads almost nothing.
    static func tests() throws -> [(name: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Support
            .deletingLastPathComponent()    // Tests
        var found: [(name: String, text: String)] = []

        guard let walk = FileManager.default.enumerator(atPath: root.path) else {
            throw WalkReadAlmostNothing(root: root.path, read: 0)
        }

        for case let path as String in walk where path.hasSuffix(".swift") {
            let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            found.append((name: URL(fileURLWithPath: path).lastPathComponent, text: text))
        }

        guard found.count > 25 else { throw WalkReadAlmostNothing(root: root.path, read: found.count) }

        return found.sorted { $0.name < $1.name }
    }
}

/// A walk of the host's sources that read almost nothing: its directory moved,
/// or its filter lets nothing through - and every guard reading the walk would
/// pass on nothing.
struct WalkReadAlmostNothing: Error, CustomStringConvertible {
    let root: String
    let read: Int

    var description: String { "the walk of \(root) read \(read) files, almost nothing" }
}
#endif
