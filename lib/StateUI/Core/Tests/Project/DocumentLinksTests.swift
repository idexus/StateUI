// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// Every document's links lead somewhere: a page moved or renamed is a link broken in each page that names it, and
/// nothing else reads those links.
@MainActor
final class DocumentLinksTests: XCTestCase {
    /// Each relative link in every Markdown document of the repository names a file or a folder that exists.
    func testEveryLinkInADocumentLeadsToAFile() throws {
        let root = SourceTree.repository
        let documents = try SourceTree.files(under: root, entering: { relative in
            SourceTree.entersSources(relative)
                && !["node_modules", "exports", "artifacts"].contains(relative.split(separator: "/").last.map(String.init) ?? "")
        }).filter { $0.hasSuffix(".md") }
        XCTAssertGreaterThan(documents.count, 100, "the walk read almost nothing")

        var broken: [String] = []
        for document in documents {
            let text = try String(contentsOf: root.appendingPathComponent(document), encoding: .utf8)
            let folder = root.appendingPathComponent(document).deletingLastPathComponent()
            for target in Self.links(in: text) {
                let path = String(target.prefix { $0 != "#" })
                guard !path.isEmpty else { continue }
                let resolved = folder.appendingPathComponent(path.removingPercentEncoding ?? path).standardizedFileURL
                if !FileManager.default.fileExists(atPath: resolved.path) { broken.append("\(document): \(target)") }
            }
        }
        XCTAssertEqual(broken, [], "a link names nothing")
    }

    /// Each link to a place in a Markdown document - `page.md#heading`, or `#heading` within its own page - finds
    /// it: a heading by the anchor GitHub gives it, or an anchor the page names; a place broken on purpose is found
    /// missing.
    func testEveryLinkToAPlaceInADocumentFindsIt() throws {
        let control = Self.missingPlaces(in: ["a.md": "# Title\n## The `look` - again\n[here](#title) [gone](#nope)"
            + " [there](#the-look---again)"])
        XCTAssertEqual(control, ["a.md: #nope"], "the check finds a place broken on purpose, and only it")
        XCTAssertEqual(Self.anchors(in: "# Foo\n# Foo-1\n# Foo\n# Foo"), ["foo", "foo-1", "foo-2", "foo-3"],
                       "a repeated heading numbered past every anchor already given, its own number included")

        let root = SourceTree.repository
        let documents = try SourceTree.files(under: root, entering: { relative in
            SourceTree.entersSources(relative)
                && !["node_modules", "exports", "artifacts"].contains(relative.split(separator: "/").last.map(String.init) ?? "")
        }).filter { $0.hasSuffix(".md") }
        var texts: [String: String] = [:]
        for document in documents {
            texts[document] = try String(contentsOf: root.appendingPathComponent(document), encoding: .utf8)
        }
        let placed = texts.values.flatMap(Self.links).filter { $0.contains("#") }.count
        XCTAssertGreaterThan(placed, 50, "the walk read almost no link to a place")
        XCTAssertEqual(Self.missingPlaces(in: texts), [], "a link names a place its page does not have")
    }

    /// The links in `documents`, by their paths from the repository's root, that name a place a Markdown page they
    /// lead to does not have.
    static func missingPlaces(in documents: [String: String]) -> [String] {
        var missing: [String] = []
        for (document, text) in documents.sorted(by: { $0.key < $1.key }) {
            for target in links(in: text) {
                guard let hash = target.firstIndex(of: "#") else { continue }
                let (path, place) = (String(target[..<hash]), String(target[target.index(after: hash)...]))
                guard path.isEmpty || path.hasSuffix(".md"), !place.isEmpty else { continue }
                let page = path.isEmpty
                    ? document
                    : URL(fileURLWithPath: "/" + document).deletingLastPathComponent()
                        .appendingPathComponent(path.removingPercentEncoding ?? path).standardizedFileURL.path.dropFirst()
                        .description
                guard let held = documents[page] else { continue }
                if !anchors(in: held).contains(place.removingPercentEncoding ?? place) {
                    missing.append("\(document): \(target)")
                }
            }
        }
        return missing
    }

    /// The anchors a page offers: GitHub's for its headings outside code blocks - lowercase, punctuation dropped,
    /// each space a hyphen, a repeated one numbered from 1 past every anchor a heading was given already - and those
    /// it names itself (`id="…"`, `name="…"`).
    static func anchors(in text: String) -> Set<String> {
        var found: Set<String> = []
        // Every anchor a heading was given, and how far each was numbered as a heading of its words repeated.
        var counts: [String: Int] = [:]
        var fenced = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                fenced.toggle()
                continue
            }
            guard !fenced else { continue }
            found.formUnion(matches(of: #"(?:id|name)="([^"]+)""#, in: String(line)))
            guard line.hasPrefix("#") else { continue }
            let heading = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces).lowercased()
            let slug = String(heading.compactMap { character -> Character? in
                if character == " " { return "-" }
                return character.isLetter || character.isNumber || character == "-" || character == "_" ? character : nil
            })
            var given = slug
            while counts[given] != nil {
                counts[slug, default: 0] += 1
                given = "\(slug)-\(counts[slug, default: 0])"
            }
            counts[given] = 0
            found.insert(given)
        }
        return found
    }

    /// The relative targets of a document's links - inline and by reference - outside its code blocks.
    static func links(in text: String) -> [String] {
        var targets: [String] = []
        var fenced = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                fenced.toggle()
                continue
            }
            guard !fenced else { continue }
            let written = String(line)
            targets += matches(of: #"\]\(<?([^)\s>]+)>?(?:\s+"[^"]*")?\)"#, in: written)
            targets += matches(of: #"^\s*\[[^\]]+\]:\s*<?(\S+?)>?(?:\s|$)"#, in: written)
        }
        return targets.filter { !$0.contains("://") && !$0.hasPrefix("mailto:") }
    }

    private static func matches(of pattern: String, in line: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(line.startIndex..., in: line)
        return expression.matches(in: line, range: range).compactMap { match in
            Range(match.range(at: 1), in: line).map { String(line[$0]) }
        }
    }
}
