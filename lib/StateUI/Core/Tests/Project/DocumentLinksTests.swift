// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// Every document's links lead somewhere: a page moved or renamed is a link broken in each page that names it, and
/// nothing else reads those links.
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
