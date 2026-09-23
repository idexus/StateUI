// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The code says what a declaration is; `docs/design/` says why.
/// Design: docs/design/README.md#the-golden-rule
final class DesignNotesTests: XCTestCase {
    /// The directories that keep the golden rule, relative to the repository.
    private static let held = ["lib/StateUI/Sources/Host"]

    /// Every `Design:` reference in a source names a note and a heading that exist.
    func testEveryDesignReferenceResolves() throws {
        let reference = try NSRegularExpression(pattern: #"Design: (docs/design/[\w./-]+\.md)#([a-z0-9-]+)"#)
        var sources = try Fixtures.allSources().map { ("lib/StateUI/Sources/\($0.path)", $0.text) }
        sources += try Fixtures.runtimeSources().map { ("lib/\($0.path)", $0.text) }
        sources += try Fixtures.testSources().map { ($0.path, $0.text) }
        var read = 0
        var broken: [String] = []

        for (path, text) in sources {
            for match in reference.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let note = Range(match.range(at: 1), in: text),
                      let section = Range(match.range(at: 2), in: text)
                else { continue }
                read += 1
                let file = Fixtures.repository.appendingPathComponent(String(text[note]))
                let headings = (try? String(contentsOf: file, encoding: .utf8)).map(Self.anchors) ?? []
                if !headings.contains(String(text[section])) {
                    broken.append("\(path): \(text[note])#\(text[section])")
                }
            }
        }

        XCTAssertGreaterThan(read, 5, "the scan read almost no reference")
        XCTAssertEqual(broken, [], "a reference names a note or a section that does not exist")
    }

    /// In every held directory, comments stay under a quarter of each file's lines.
    func testTheHeldSourcesKeepTheGoldenRule() throws {
        var over: [String] = []

        for directory in Self.held {
            let root = Fixtures.repository.appendingPathComponent(directory)
            let files = try Fixtures.files(under: root, entering: { _ in true }).filter { $0.hasSuffix(".swift") }
            XCTAssertFalse(files.isEmpty, "\(directory) holds no source")

            for file in files {
                let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
                let (comments, lines) = Self.measure(text)
                if comments * 4 >= lines { over.append("\(directory)/\(file): \(comments) of \(lines)") }
            }
        }

        XCTAssertEqual(over, [], "comments reach a quarter of these files; the reasons belong in docs/design")
    }

    /// The anchors of a note's headings: lowercase, letters and digits, one hyphen per gap.
    static func anchors(_ note: String) -> Set<String> {
        var found: Set<String> = []
        for line in note.split(separator: "\n") where line.hasPrefix("#") {
            let heading = line.drop { $0 == "#" }.lowercased()
            var anchor = ""
            for character in heading {
                if character.isLetter || character.isNumber {
                    anchor.append(character)
                } else if character == " " || character == "-", !anchor.isEmpty, anchor.last != "-" {
                    anchor.append("-")
                }
            }
            if anchor.last == "-" { anchor.removeLast() }
            found.insert(anchor)
        }
        return found
    }

    /// Counted comment lines and counted lines: the licence header aside, and the
    /// `///` documentation of a public declaration or an enum case, which the editor shows on `.`.
    static func measure(_ text: String) -> (comments: Int, lines: Int) {
        var lines = text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        let body = Array(lines.drop { $0.hasPrefix("// SPDX-") })
        let trimmed = body.map { $0.trimmingCharacters(in: .whitespaces) }
        var exempt = Set<Int>()
        var index = 0

        while index < trimmed.count {
            guard trimmed[index].hasPrefix("///") else { index += 1; continue }
            var end = index
            while end < trimmed.count, trimmed[end].hasPrefix("///") { end += 1 }
            var target = end
            while target < trimmed.count, trimmed[target].hasPrefix("@"), !isPublic(trimmed[target]),
                  !trimmed[target].hasPrefix("@_spi") { target += 1 }
            let declaration = target < trimmed.count ? trimmed[target] : ""
            if isPublic(declaration) || declaration.hasPrefix("case ") { exempt.formUnion(index..<end) }
            index = end
        }

        var comments = 0
        var inBlock = false
        for (number, line) in trimmed.enumerated() where !exempt.contains(number) {
            if inBlock {
                comments += 1
                if line.contains("*/") { inBlock = false }
            } else if line.hasPrefix("/*") {
                comments += 1
                inBlock = !line.dropFirst(2).contains("*/")
            } else if line.hasPrefix("//") {
                comments += 1
            }
        }
        return (comments, trimmed.count - exempt.count)
    }

    private static func isPublic(_ line: String) -> Bool {
        (" " + line).range(of: #"\spublic[\s(]"#, options: .regularExpression) != nil
    }
}
