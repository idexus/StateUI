// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The Gallery's own source files, read as text.
enum GallerySources {
    /// The Gallery's package.
    static let gallery = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // GalleryTests
        .deletingLastPathComponent()    // Tests
        .deletingLastPathComponent()    // Gallery

    /// The text files under `folder` of the Gallery's package, by their path in it, line ends as `\n`. A path is
    /// written with `/` on every system - Windows walks a folder with `\` - so what is written from it is the same
    /// on each.
    static func files(under folder: String, extensions: Set<String>) throws -> [(path: String, text: String)] {
        let root = gallery.appendingPathComponent(folder)
        guard let walk = FileManager.default.enumerator(atPath: root.path) else { return [] }

        return try walk.compactMap { ($0 as? String)?.replacingOccurrences(of: "\\", with: "/") }
            .filter { extensions.contains(($0 as NSString).pathExtension) && !$0.contains(".build/") }
            .sorted()
            .map { relative in
                let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
                return ("\(folder)/\(relative)", text.replacingOccurrences(of: "\r\n", with: "\n"))
            }
    }
}
