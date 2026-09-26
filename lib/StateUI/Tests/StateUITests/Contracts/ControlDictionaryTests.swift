// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

/// The control dictionary - docs/controls - is the contracts and the verdicts of
/// the hosts' test runs rendered, and the verdicts are held to the contracts.
///
/// A page that differs from what `ControlDictionary` renders fails here, and so
/// does a page no contract has, and an index or a platform contract whose
/// tables are not the rendered ones. `STATEUI_UPDATE_DOCS=1` writes them all
/// and removes a page whose contract is gone - then read the diff.
///
/// The verdicts are read where they are rendered, so they are held here: a
/// line that is no verdict, and a verdict on what no contract of its element
/// declares, fail.
final class ControlDictionaryTests: XCTestCase {
    private static let folder = SourceTree.repository.appendingPathComponent("docs/controls")

    private static let hint = "Run the host's suite with STATEUI_UPDATE_EXPORTS=1, or change the contract, then run "
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
            let url = SourceTree.repository.appendingPathComponent(path)
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
            contentsOf: SourceTree.repository.appendingPathComponent("docs/platform-contract.md"), encoding: .utf8
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

    // MARK: - The verdicts

    /// Every verdict a host's run wrote is about an element, or a member a contract declares on that element,
    /// itself or through a tier it wears: a verdict on nothing marks nothing.
    func testEveryVerdictNamesAMemberOfItsElement() throws {
        var read = 0
        for (host, folder) in ControlDictionary.folders.sorted(by: { $0.key < $1.key }) {
            for verdict in try ControlDictionary.verdicts(folder) {
                read += 1
                let element = LibraryContracts.elements.first { $0.nodeType.name == verdict.element }
                let declared = element.map { element in
                    verdict.member.map { member in
                        element.worn.contains { contract in contract.members.contains { $0.name == member } }
                    } ?? true
                } ?? false
                if !declared {
                    XCTFail("exports/marks/\(folder) says \(verdict), which no contract of that element declares (\(host))")
                }
            }
        }
        XCTAssertGreaterThan(read, 10, "the verdicts read almost nothing")
    }

    /// A mark is the run's alone: a cell a run gave no verdict, or one it said is not realized, is empty; one the
    /// driver could not reach is empty and says why.
    func testAMarkIsTheRunsVerdictAlone() {
        let column = ControlDictionary.Column(host: "WinUI 3", verdicts: [
            "Button": HostVerdict(element: "Button", member: nil, mark: .proven),
            "Button.clicked": HostVerdict(element: "Button", member: "clicked", mark: .proven),
            "Button.icon": HostVerdict(element: "Button", member: "icon", mark: .notRealized),
            "TextField.submitted": HostVerdict(element: "TextField", member: "submitted", mark: .cannot("submit - Keys.")),
            "Map": HostVerdict(element: "Map", member: nil, mark: .notPlanned(reason: "No maps.")),
        ])

        XCTAssertEqual(column.mark(of: nil, on: "Button").mark, "✅")
        XCTAssertEqual(column.mark(of: "clicked", on: "Button").mark, "✅")
        XCTAssertEqual(column.mark(of: "icon", on: "Button").mark, "")
        XCTAssertEqual(column.mark(of: "pressed", on: "Button").mark, "", "no verdict, no mark")
        XCTAssertEqual(column.mark(of: "submitted", on: "TextField").mark, "")
        XCTAssertEqual(column.mark(of: "submitted", on: "TextField").note, "cannot submit - Keys.")
        XCTAssertEqual(column.mark(of: nil, on: "Map").mark, "–")
        XCTAssertTrue(column.judges("Button"))
        XCTAssertTrue(column.judges("Map"))
        XCTAssertFalse(column.judges("TextField"), "a run that made no verdict of the element itself judged it not")
    }

    /// A row whose members are all realized or not planned is met, one of which none is planned is –, and the
    /// counts say each mark's number.
    func testNotPlannedMeetsTheContractInARow() {
        XCTAssertEqual(ControlDictionary.grouped(["✅", "–"]), "✅")
        XCTAssertEqual(ControlDictionary.grouped(["–", "–"]), "–")
        XCTAssertEqual(ControlDictionary.grouped(["☑️", "–"]), "☑️")
        XCTAssertEqual(ControlDictionary.grouped(["✅", ""]), "")
        XCTAssertEqual(ControlDictionary.counted(.init(done: 3, partial: 1, notPlanned: 2)), "3 ✅ · 1 ☑️ · 2 –")
        XCTAssertEqual(ControlDictionary.Marks(done: 3, partial: 1, notPlanned: 2).met, 5)
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
