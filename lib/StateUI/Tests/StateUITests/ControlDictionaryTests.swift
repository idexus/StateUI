// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The control dictionary - docs/controls - against the code it describes.
///
/// An entry - a control, or a part of an application's structure - lists the
/// members its sources declare, then one section per protocol it inherits; a
/// tier's file lists that protocol's members. A property or a handler added,
/// renamed or removed without its row fails here, and
/// `python3 .scripts/controls-dictionary.py` rewrites the member lists,
/// keeping every mark and note already written. A member is counted by the
/// rule every other test here uses - `Fixtures.propertyKeys(in:)` for a
/// property, `Fixtures.handlerKeys(in:)` for a handler.
///
/// A ✅* - realized, but incomplete - says in its note what is missing, or it
/// is a claim nobody can check; and the counts the index and the platform
/// contract show are taken from the files, so every mark lives in one place.
final class ControlDictionaryTests: XCTestCase {
    private struct Row {
        let token: String
        let marks: [String]
        let note: String
    }

    private static let folder = Fixtures.repository.appendingPathComponent("docs/controls")
    private static let platforms = ["MAUI", "AppKit", "UIKit", "GTK 4", "Android Views", "WinUI 3", "Web"]

    private func read(_ path: String) throws -> String {
        try String(contentsOf: Self.folder.appendingPathComponent(path), encoding: .utf8)
    }

    /// Every entry the dictionary holds: each file beside the index.
    private func entries() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: Self.folder.path)
            .filter { $0.hasSuffix(".md") && $0 != "README.md" }
            .map { String($0.dropLast(3)) }
            .sorted()
    }

    private func tiers() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: Self.folder.appendingPathComponent("tiers").path)
            .filter { $0.hasSuffix(".md") }
            .map { String($0.dropLast(3)) }
            .sorted()
    }

    /// A member cell's token: `icon` is `icon`, `onClicked` (`clicked`) is `clicked`.
    private func token(_ cell: String) -> String {
        cell.split(separator: "`")
            .map(String.init)
            .filter { !$0.contains("(") && !$0.contains(")") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .last ?? cell
    }

    private func cells(_ line: String) -> [String] {
        line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Every `## ` section of an entry's file, with the rows under it.
    private func sections(_ entry: String) throws -> [(heading: String, rows: [Row])] {
        var result: [(heading: String, rows: [Row])] = []
        for line in try read("\(entry).md").components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                result.append((line, []))
            } else if line.hasPrefix("| `"), !result.isEmpty {
                // "", member, kind, a mark per platform, note, ""
                let row = cells(line)
                let marks = Array(row.dropFirst(3).prefix(Self.platforms.count))
                let note = row.count > 3 + Self.platforms.count ? row[3 + Self.platforms.count] : ""
                result[result.count - 1].rows.append(Row(token: token(row[1]), marks: marks, note: note))
            }
        }
        return result
    }

    private func own(_ entry: String) throws -> Set<String> {
        Set(try sections(entry).first { $0.heading == "## \(entry)'s own members" }?.rows.map(\.token) ?? [])
    }

    private func tierTokens(_ tier: String) throws -> Set<String> {
        Set(try read("tiers/\(tier).md").components(separatedBy: "\n")
            .filter { $0.hasPrefix("| `") }
            .map { token(cells($0)[1]) })
    }

    /// The sources a file says its members are declared in, as paths under
    /// lib/StateUI/Sources - `Views/Label.swift`.
    private func declaredFiles(_ path: String) throws -> [String] {
        let prefix = "lib/StateUI/Sources/"
        guard let line = try read(path).components(separatedBy: "\n").first(where: { $0.hasPrefix("Declared in ") })
        else { return [] }
        return line.components(separatedBy: "`")
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private func declared(in file: String) throws -> Set<String> {
        try Fixtures.propertyKeys(in: file).union(Fixtures.handlerKeys(in: file))
    }

    func testEveryEntryHasItsFileAndTheIndexNamesIt() throws {
        let index = try read("README.md")
        XCTAssertFalse(try entries().isEmpty)
        for entry in try entries() {
            XCTAssertTrue(index.contains("](\(entry).md)"), "docs/controls/README.md does not name \(entry)")
            XCTAssertFalse(try declaredFiles("\(entry).md").isEmpty, "\(entry).md does not say where it is declared")
        }
    }

    /// An entry's own rows are members its sources declare, and every member a
    /// source declares is an own row of an entry naming it - equality for a
    /// control alone in its file, and for a source several entries share, such
    /// as the window's and the page's `Application.swift`, their rows together.
    func testAnEntrysOwnMembersAreWhatItsSourcesDeclare() throws {
        var claimed: [String: Set<String>] = [:]
        for entry in try entries() {
            let files = try declaredFiles("\(entry).md")
            let listed = try own(entry)
            let code = try files.reduce(into: Set<String>()) { $0.formUnion(try declared(in: $1)) }
            XCTAssertTrue(listed.isSubset(of: code), """
                docs/controls/\(entry).md lists \(listed.subtracting(code).sorted()), which \(files) do \
                not declare. Run python3 .scripts/controls-dictionary.py.
                """)
            for file in files {
                claimed[file, default: []].formUnion(listed)
            }
        }
        for (file, listed) in claimed.sorted(by: { $0.key < $1.key }) {
            let missing = try declared(in: file).subtracting(listed)
            XCTAssertTrue(missing.isEmpty, """
                \(file) declares \(missing.sorted()), which no entry naming it lists as its own. Run \
                python3 .scripts/controls-dictionary.py.
                """)
        }
    }

    func testATiersSectionIsWhatItsFileLists() throws {
        for entry in try entries() {
            let mine = try own(entry)
            for part in try sections(entry) where part.heading.hasPrefix("## From [") {
                let tier = String(part.heading.dropFirst("## From [".count).prefix(while: { $0 != "]" }))
                XCTAssertEqual(Set(part.rows.map(\.token)), try tierTokens(tier).subtracting(mine),
                               "\(entry)'s section from \(tier) is not what tiers/\(tier).md lists")
            }
        }
    }

    /// Every member of every source the dictionary names - an entry's or a
    /// tier's - is a row of an entry, where it carries its marks.
    func testEveryMemberOfADescribedFileHasARow() throws {
        var listed = Set<String>()
        var files = Set<String>()
        for entry in try entries() {
            files.formUnion(try declaredFiles("\(entry).md"))
            listed.formUnion(try sections(entry).flatMap { $0.rows.map(\.token) })
        }
        for tier in try tiers() {
            files.formUnion(try declaredFiles("tiers/\(tier).md"))
        }
        for file in files.sorted() {
            let missing = try declared(in: file).subtracting(listed)
            XCTAssertTrue(missing.isEmpty, """
                \(file) declares \(missing.sorted()), which no entry in docs/controls lists. Run \
                python3 .scripts/controls-dictionary.py.
                """)
        }
    }

    func testAPartialMarkSaysWhatIsMissing() throws {
        for entry in try entries() {
            for part in try sections(entry) {
                for row in part.rows {
                    XCTAssertTrue(row.marks.allSatisfy { ["", "✅", "✅*"].contains($0) },
                                  "\(entry): \(row.token) carries a mark other than ✅ or ✅*")
                    if row.marks.contains("✅*") {
                        XCTAssertFalse(row.note.isEmpty, "\(entry): \(row.token) is ✅* without saying what is missing")
                    }
                }
            }
        }
    }

    /// The counts in the index and in docs/platform-contract.md are the files'
    /// own marks, so a mark changed in one place changes everywhere.
    func testTheCountsAreTakenFromTheFiles() throws {
        let index = try read("README.md")
        let contract = try String(
            contentsOf: Fixtures.repository.appendingPathComponent("docs/platform-contract.md"), encoding: .utf8)
        XCTAssertTrue(contract.contains("<!-- dictionary:begin -->"))
        for entry in try entries() {
            let rows = try sections(entry).flatMap(\.rows)
            let counts = Self.platforms.indices.map { k -> String in
                let done = rows.filter { $0.marks.count > k && $0.marks[k] == "✅" }.count
                let partial = rows.filter { $0.marks.count > k && $0.marks[k] == "✅*" }.count
                guard done + partial > 0 else { return "" }
                return partial > 0 ? "\(done) ✅ · \(partial) ✅*" : "\(done) ✅"
            }
            let cells = " | \(rows.count) | " + counts.joined(separator: " | ") + " |"
            XCTAssertTrue(index.contains("[\(entry)](\(entry).md)" + cells),
                          "docs/controls/README.md does not show \(entry)'s counts")
            XCTAssertTrue(contract.contains("[\(entry)](controls/\(entry).md)" + cells),
                          "docs/platform-contract.md does not show \(entry)'s counts")
        }
    }
}
