// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

/// The control dictionary - docs/controls - is the contracts and the hosts'
/// declarations rendered, and the declarations are held to the contracts.
///
/// A page that differs from what `ControlDictionary` renders fails here, and so
/// does a page no contract has, and an index or a platform contract whose
/// tables are not the rendered ones. `STATEUI_UPDATE_DOCS=1` writes them all
/// and removes a page whose contract is gone - then read the diff.
///
/// The declarations are read where they are rendered, so they are held here:
/// a record naming what no contract declares, a record written twice, a
/// partial one that does not say what is missing, and an unrealized or
/// viewless name that is no element all fail.
final class ControlDictionaryTests: XCTestCase {
    private static let folder = Fixtures.repository.appendingPathComponent("docs/controls")

    private static let hint = "Record the realization in its host's declaration or change the contract, then run "
        + "STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests and read the diff."

    private static var updating: Bool {
        ProcessInfo.processInfo.environment["STATEUI_UPDATE_DOCS"] == "1"
    }

    // MARK: - The documents

    /// Every page is its contract rendered, and every page belongs to a
    /// contract.
    func testEveryPageIsItsContractRendered() throws {
        let pages = try ControlDictionary().pages()
        let files = try Self.files()

        if Self.updating {
            try FileManager.default.createDirectory(
                at: Self.folder.appendingPathComponent("tiers"), withIntermediateDirectories: true)

            for (path, text) in pages {
                try text.write(to: Self.folder.appendingPathComponent(path), atomically: true, encoding: .utf8)
            }

            for path in files where pages[path] == nil {
                try FileManager.default.removeItem(at: Self.folder.appendingPathComponent(path))
            }

            return
        }

        for (path, text) in pages.sorted(by: { $0.key < $1.key }) {
            guard let written = try? String(contentsOf: Self.folder.appendingPathComponent(path), encoding: .utf8)
            else {
                XCTFail("docs/controls/\(path) is missing. \(Self.hint)")
                continue
            }

            if let difference = Self.difference(written, text) {
                XCTFail("docs/controls/\(path) is not what its contract renders: \(difference). \(Self.hint)")
            }
        }

        for path in files where pages[path] == nil {
            XCTFail("docs/controls/\(path) is the page of no contract. \(Self.hint)")
        }
    }

    /// The index and the platform contract carry the rendered tables, each
    /// between its markers.
    func testTheIndexAndThePlatformContractCarryTheRenderedTables() throws {
        let dictionary = try ControlDictionary()

        for (path, blocks) in [("docs/controls/README.md", dictionary.indexBlocks()),
                               ("docs/platform-contract.md", dictionary.contractBlocks())] {
            let url = Fixtures.repository.appendingPathComponent(path)
            let written = try String(contentsOf: url, encoding: .utf8)
            var rendered = written

            for (name, content) in blocks.sorted(by: { $0.key < $1.key }) {
                rendered = try ControlDictionary.replacing(block: name, in: rendered, with: content)
            }

            if Self.updating {
                try rendered.write(to: url, atomically: true, encoding: .utf8)
            } else if let difference = Self.difference(written, rendered) {
                XCTFail("\(path) does not carry the rendered tables: \(difference). \(Self.hint)")
            }
        }
    }

    /// The native control mapping names every element exactly once - every
    /// page takes its native counterparts from it - and names nothing else
    /// but `ItemsView`, the planned collection with no node type of its own.
    func testTheNativeMappingNamesEveryElementOnce() throws {
        let lines = try String(
            contentsOf: Fixtures.repository.appendingPathComponent("docs/platform-contract.md"), encoding: .utf8
        ).components(separatedBy: "\n")
        let start = try XCTUnwrap(lines.firstIndex(of: "## Native control mapping"))
        var named: [String] = []

        for line in lines[(start + 1)...] {
            if line.hasPrefix("## ") { break }
            guard line.hasPrefix("| `"), let first = ControlDictionary.cells(of: line).first else { continue }

            named += ControlDictionary.backticked(first)
        }

        let elements = Set(LibraryContracts.elements.map { $0.name })
        let twice = Dictionary(grouping: named) { $0 }.filter { $0.value.count > 1 }.keys.sorted()

        XCTAssertEqual(twice, [], "the mapping names these elements twice")
        XCTAssertEqual(elements.subtracting(named).sorted(), [], "the mapping names no counterpart of these elements")
        XCTAssertEqual(Set(named).subtracting(elements).subtracting(["ItemsView"]).sorted(), [],
                       "the mapping names these, and no element is one")
    }

    // MARK: - The declarations

    /// Every record names a contract and a member that contract declares or
    /// wears, and every unrealized or viewless name is an element.
    func testEveryRecordNamesAMemberOfWhatItNames() throws {
        let contracts = Dictionary(LibraryContracts.all.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let elements = Set(LibraryContracts.elements.map { $0.name })
        var wrong: [String] = []

        for declaration in try ControlDictionary.declarations() {
            XCTAssertGreaterThan(declaration.records.count, 100, "\(declaration.source): the scan read almost nothing")

            for record in declaration.records {
                guard let owner = contracts[record.owner] else {
                    wrong.append("\(declaration.host): \(record.owner) is no contract")
                    continue
                }

                if !owner.worn.contains(where: { tier in tier.members.contains { $0.name == record.member } }) {
                    wrong.append("\(declaration.host): \(record.owner) declares and wears no \(record.member)")
                }
            }

            for name in declaration.unrealized.union(declaration.viewless).sorted() where !elements.contains(name) {
                wrong.append("\(declaration.host): \(name), unrealized or viewless, is no element")
            }
        }

        XCTAssertEqual(wrong, [], "a declaration names what the contracts do not")
    }

    /// No host records one member of one contract twice.
    func testEveryRecordIsWrittenOnce() throws {
        for declaration in try ControlDictionary.declarations() {
            var seen: Set<String> = []

            for record in declaration.records {
                if !seen.insert("\(record.owner).\(record.member)").inserted {
                    XCTFail("\(declaration.source) records \(record.member) on \(record.owner) twice")
                }
            }
        }
    }

    /// A member realized in part says what is missing: a ✅* nobody can check
    /// is no mark at all.
    func testAPartialRecordSaysWhatIsMissing() throws {
        for declaration in try ControlDictionary.declarations() {
            for record in declaration.records where record.missing?.isEmpty == true {
                XCTFail("\(declaration.source) records \(record.member) on \(record.owner) in part, "
                    + "and does not say what is missing")
            }
        }
    }

    // MARK: - The contracts

    /// Every tier is worn by an element: a tier nobody wears declares members
    /// no host is ever asked for.
    func testEveryTierIsWorn() {
        for tier in LibraryContracts.tiers {
            let worn = LibraryContracts.elements.contains { element in
                element.worn.contains { ObjectIdentifier($0) == ObjectIdentifier(tier) }
            }

            XCTAssertTrue(worn, "\(tier.name) is worn by no element")
        }
    }

    /// Each event is heard through one `on…` modifier, whichever element hears
    /// it, so its row names one.
    func testEveryEventIsHeardThroughOneModifier() throws {
        for (event, spellings) in try ControlDictionary.handlerSpellings() where spellings.count > 1 {
            XCTFail("\(event) is heard through \(spellings.sorted())")
        }
    }

    // MARK: - Support

    /// Every page the dictionary holds, by its path under docs/controls - the
    /// index left out.
    private static func files() throws -> [String] {
        let manager = FileManager.default
        let pages = try manager.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasSuffix(".md") && $0 != "README.md" }
        let tiers = try manager.contentsOfDirectory(atPath: folder.appendingPathComponent("tiers").path)
            .filter { $0.hasSuffix(".md") }
            .map { "tiers/" + $0 }

        return (pages + tiers).sorted()
    }

    /// Where a written text first parts from the rendered one; nil where they
    /// agree.
    private static func difference(_ written: String, _ rendered: String) -> String? {
        guard written != rendered else { return nil }

        let writtenLines = written.components(separatedBy: "\n")
        let renderedLines = rendered.components(separatedBy: "\n")

        for index in 0..<max(writtenLines.count, renderedLines.count) {
            let was = index < writtenLines.count ? writtenLines[index] : "(nothing)"
            let should = index < renderedLines.count ? renderedLines[index] : "(nothing)"

            if was != should {
                return "line \(index + 1) reads \"\(was)\" and should read \"\(should)\""
            }
        }

        return "they differ"
    }
}
