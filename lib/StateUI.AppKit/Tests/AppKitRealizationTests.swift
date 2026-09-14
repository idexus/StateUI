// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUIAppKit
import XCTest

/// The AppKit column of the control dictionary - docs/controls - is what this
/// host declares it realizes, `AppKitRealization`: a realization without its
/// mark, or a mark without its realization, fails here.
///
/// A record names an entry of the dictionary or a tier its members come from;
/// an entry's own record wins over its tier's, and an entry this host shows as
/// unsupported carries no mark at all. `python3 .scripts/controls-dictionary.py`
/// writes the column from the records.
final class AppKitRealizationTests: XCTestCase {
    private struct Row {
        let entry: String
        let tier: String?
        let member: String
        let mark: String
        let note: String
    }

    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // Tests
        .deletingLastPathComponent()    // StateUI.AppKit
        .deletingLastPathComponent()    // lib
        .deletingLastPathComponent()    // the repository
        .appendingPathComponent("docs/controls")

    private func read(_ path: String) throws -> String {
        try String(contentsOf: Self.folder.appendingPathComponent(path), encoding: .utf8)
    }

    private func files(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasSuffix(".md") && $0 != "README.md" }
            .map { String($0.dropLast(3)) }
            .sorted()
    }

    private func entries() throws -> [String] { try files(in: Self.folder) }

    private func tiers() throws -> [String] { try files(in: Self.folder.appendingPathComponent("tiers")) }

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

    /// Every row of every entry, with the tier its section comes from.
    private func rows() throws -> [Row] {
        var result: [Row] = []
        for entry in try entries() {
            var tier: String?
            for line in try read("\(entry).md").components(separatedBy: "\n") {
                if line.hasPrefix("## From [") {
                    tier = String(line.dropFirst("## From [".count).prefix { $0 != "]" })
                } else if line.hasPrefix("## ") {
                    tier = nil
                } else if line.hasPrefix("| `") {
                    // "", member, kind, AppKit, UIKit, GTK 4, Android Views, WinUI 3, Web, note, ""
                    let row = cells(line)
                    result.append(Row(entry: entry, tier: tier, member: token(row[1]), mark: row[3], note: row[9]))
                }
            }
        }
        return result
    }

    private func tierMembers(_ tier: String) throws -> Set<String> {
        Set(try read("tiers/\(tier).md").components(separatedBy: "\n")
            .filter { $0.hasPrefix("| `") }
            .map { token(cells($0)[1]) })
    }

    /// The mark and note the records give a row.
    private func expected(_ row: Row) -> (mark: String, note: String) {
        guard !AppKitRealization.unrealized.contains(row.entry) else { return ("", "") }

        for owner in [row.entry] + [row.tier].compactMap({ $0 }) {
            switch AppKitRealization.records.first(where: { $0.owner == owner && $0.member == row.member }) {
            case .complete?: return ("✅", "")
            case .partial(_, _, let missing)?: return ("✅*", missing)
            case nil: continue
            }
        }
        return ("", "")
    }

    func testTheDictionarysAppKitColumnIsWhatThisHostRealizes() throws {
        let rows = try rows()
        XCTAssertFalse(rows.isEmpty)
        for row in rows {
            let (mark, note) = expected(row)
            XCTAssertEqual(row.mark, mark, """
                docs/controls/\(row.entry).md marks \(row.member) "\(row.mark)" for AppKit, and \
                AppKitRealization says "\(mark)". Record the realization, then run \
                python3 .scripts/controls-dictionary.py.
                """)
            if mark == "✅*" {
                XCTAssertEqual(row.note, note, "\(row.entry): \(row.member)'s note is not what AppKitRealization says")
            }
        }
    }

    func testEveryRecordNamesAMemberTheDictionaryLists() throws {
        let entries = Set(try entries())
        let tiers = Set(try tiers())
        let rows = try rows()
        for record in AppKitRealization.records {
            if entries.contains(record.owner) {
                XCTAssertTrue(rows.contains { $0.entry == record.owner && $0.member == record.member },
                              "AppKitRealization records \(record.member) on \(record.owner), which has no such row")
            } else if tiers.contains(record.owner) {
                XCTAssertTrue(try tierMembers(record.owner).contains(record.member),
                              "AppKitRealization records \(record.member) on the tier \(record.owner), which lists no such member")
            } else {
                XCTFail("AppKitRealization records \(record.member) on \(record.owner), which docs/controls does not hold")
            }
        }
        for entry in AppKitRealization.unrealized {
            XCTAssertTrue(entries.contains(entry), "AppKitRealization.unrealized names \(entry), which docs/controls does not hold")
        }
    }

    func testEveryRecordIsWrittenOnce() {
        var seen: Set<String> = []
        for record in AppKitRealization.records {
            XCTAssertTrue(seen.insert("\(record.owner).\(record.member)").inserted,
                          "AppKitRealization records \(record.member) on \(record.owner) twice")
        }
    }
}
