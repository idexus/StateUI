// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A sample's source file, and the code its page shows.
struct SampleSource {
    /// Its file name, unique among the Gallery's sources.
    let name: String

    /// Each `static let code`, as the page shows it.
    let code: [String]

    /// The Gallery's package.
    static let gallery = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // GalleryTests
        .deletingLastPathComponent()    // Tests
        .deletingLastPathComponent()    // Gallery

    /// Every sample of the Gallery's sources, by name.
    static func all() throws -> [SampleSource] {
        try files(under: "Sources", extensions: ["swift"]).compactMap { path, text in
            let code = literals(in: text, opening: ["static let code = \"\"\""])
            return code.isEmpty ? nil : SampleSource(name: (path as NSString).lastPathComponent, code: code)
        }
        .sorted { $0.name < $1.name }
    }

    /// The text files under `folder` of the Gallery's package, by their path in it, line ends as `\n`.
    static func files(under folder: String, extensions: Set<String>) throws -> [(path: String, text: String)] {
        let root = gallery.appendingPathComponent(folder)
        guard let walk = FileManager.default.enumerator(atPath: root.path) else { return [] }

        return try walk.compactMap { $0 as? String }
            .filter { extensions.contains(($0 as NSString).pathExtension) && !$0.contains(".build/") }
            .sorted()
            .map { relative in
                let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
                return ("\(folder)/\(relative)", text.replacingOccurrences(of: "\r\n", with: "\n"))
            }
    }

    /// The multi-line string literals of `text` that open after one of `openers`, as Swift reads them: indented by
    /// their closing delimiter, their escapes resolved.
    static func literals(in text: String, opening openers: [String]) -> [String] {
        var found: [String] = []
        var lines: [Substring] = []
        var open = false

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if open, trimmed.hasPrefix("\"\"\"") {
                let indent = line.prefix { $0 == " " }.count
                found.append(unescaped(lines.map { $0.count >= indent ? String($0.dropFirst(indent)) : "" }
                    .joined(separator: "\n")))
                open = false
            } else if open {
                lines.append(line)
            } else if trimmed.hasSuffix("\"\"\""), openers.contains(where: { trimmed.contains($0) }) {
                open = true
                lines = []
            }
        }

        return found
    }

    /// A string literal's text with its escapes resolved.
    static func unescaped(_ literal: String) -> String {
        var result = ""
        var characters = literal.makeIterator()

        while let character = characters.next() {
            guard character == "\\", let next = characters.next() else {
                result.append(character)
                continue
            }

            switch next {
            case "n": result.append("\n")
            case "t": result.append("\t")
            case "0": result.append("\0")
            case "\n": break
            default: result.append(next)
            }
        }

        return result
    }
}
