// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The whole contract, against everything that names the library's vocabulary:
// every node type is one element's, every property and event of the ownership
// table a member, every act a member of exactly one contract; the platform
// contract's vocabulary is the contracts' own, and every name its tables use is
// in the contract; every row of the control dictionary is a member, of the
// row's kind, of a contract its entry describes.

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

final class CompleteContractTests: XCTestCase {
    /// One member, with the contract declaring it.
    private struct Declared {
        let contract: any Contract.Type
        let member: any ContractMember

        var kind: MemberFacts.Kind? { (member as? any DeclaredMember)?.facts.kind }
    }

    /// Every member of every library contract.
    private var declared: [Declared] {
        LibraryContracts.all.flatMap { contract in
            contract.members.map { Declared(contract: contract, member: $0) }
        }
    }

    /// The names the contracts declare members of one kind under.
    private func names(of kind: MemberFacts.Kind) -> Set<String> {
        Set(declared.filter { $0.kind == kind }.map(\.member.name))
    }

    // MARK: - The vocabulary

    /// Every node type the library declares is the type of exactly one element
    /// contract, and no element contract declares a type the library does not.
    func testEveryNodeTypeIsExactlyOneElementsContract() {
        var contracts: [String: [String]] = [:]

        for element in LibraryContracts.elements {
            contracts[element.nodeType.name, default: []].append(String(describing: element))
        }

        let types = Set(HostContract.controls.keys.map(\.name))
        XCTAssertEqual(types.subtracting(contracts.keys).sorted(), [], "a node type with no contract")
        XCTAssertEqual(Set(contracts.keys).subtracting(types).sorted(), [], "a contract for no node type")
        XCTAssertEqual(contracts.filter { $0.value.count > 1 }.keys.sorted(), [], "a node type with two contracts")
    }

    /// Every property and every event the ownership table names is a member of
    /// a contract - the other way round, `LibraryContractTests` holds every
    /// member to a name the table owns.
    func testEveryPropertyAndEventIsAMember() {
        XCTAssertEqual(
            Set(HostContract.properties.keys.map(\.name)).subtracting(names(of: .property)).sorted(), [],
            "a property no contract declares")
        XCTAssertEqual(
            Set(HostContract.events.keys.map(\.name)).subtracting(names(of: .event)).sorted(), [],
            "an event no contract declares")
    }

    /// Every act the library declares is a member of exactly one contract,
    /// and every act member is one the library declares.
    func testEveryActIsAMemberOfExactlyOneContract() throws {
        let acts = Set(try Fixtures.text(in: "Core/Tokens.swift")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("static let ") }
            .compactMap { $0.components(separatedBy: "= Act(\"").dropFirst().first?.prefix { $0 != "\"" } }
            .map(String.init))
        var owners: [String: [String]] = [:]

        for item in declared where item.kind == .act {
            owners[item.member.name, default: []].append(item.contract.name)
        }

        XCTAssertGreaterThan(acts.count, 15, "the scan read almost nothing")
        XCTAssertEqual(acts.subtracting(owners.keys).sorted(), [], "an act no contract declares")
        XCTAssertEqual(Set(owners.keys).subtracting(acts).sorted(), [], "an act member no token declares")
        XCTAssertEqual(owners.filter { $0.value.count > 1 }.keys.sorted(), [], "an act declared twice")
    }

    // MARK: - The platform contract

    /// The platform contract's "Complete host vocabulary" is the contracts'
    /// own: exactly the element contracts' node types, and exactly the names
    /// their properties and events are declared under.
    func testThePlatformContractsVocabularyIsTheContracts() throws {
        let document = try Self.platformContract()

        XCTAssertEqual(
            Self.difference(Self.listed(under: "### Controls and structural nodes", in: document),
                            Set(LibraryContracts.elements.map { $0.nodeType.name })), [],
            "the node types the platform contract lists")
        XCTAssertEqual(
            Self.difference(Self.listed(under: "### Properties", in: document), names(of: .property)), [],
            "the properties the platform contract lists")
        XCTAssertEqual(
            Self.difference(Self.listed(under: "### Events", in: document), names(of: .event)), [],
            "the events the platform contract lists")
    }

    /// Every name a row of the platform contract's tables uses is in the
    /// contract - a node type, a member, a handler's `on…` spelling of an
    /// event member - or one of the few pieces of core API a row names beside
    /// them, each listed here with what it is.
    func testEveryNameThePlatformContractsTablesUseIsInTheContract() throws {
        let document = try Self.platformContract()
        let sections = ["## Control creation", "## Shared view members", "## Control properties and handlers"]
        let coreAPI: Set<String> = [
            // Identity, aiming and reactions every element has, which no host realizes.
            "id", "aim", "onChanged", "samples", "engine",
            // Motion, which the differ writes beside the values it moves.
            "motion", "MotionValues", "MotionLanes",
            // Modifiers whose member is named beside them in the same row.
            "isFocused", "spans", "titleView",
            // The planned native collection, a StateUI composition today.
            "ItemsView",
            // The Swift names a row's members are written with: the type a Span
            // is made with, Swift's own library owning `Span`, and the group a
            // window's session metadata is declared on.
            "TextSpan", "WindowGroup",
        ]
        let types = Set(LibraryContracts.elements.map { $0.nodeType.name })
        let members = Set(declared.map(\.member.name))
        let events = names(of: .event)
        var stranger: [String] = []

        for section in sections {
            for name in Self.backticked(inTableOf: section, in: document).sorted() {
                let handler = name.hasPrefix("on") && name.count > 2
                    && events.contains(name.dropFirst(2).prefix(1).lowercased() + name.dropFirst(3))
                if !types.contains(name) && !members.contains(name) && !handler && !coreAPI.contains(name) {
                    stranger.append("\(section): `\(name)`")
                }
            }
        }

        XCTAssertEqual(stranger, [], "a name the platform contract uses that the contract does not declare")
    }

    // MARK: - The control dictionary

    /// Every row of the control dictionary is a member of a contract its entry
    /// describes, of the kind its row says: an entry's own rows belong to the
    /// node types its sources build, a section taken from a tier to that tier,
    /// and a tier's own file to the tier.
    func testEveryDictionaryRowIsAMember() throws {
        let folder = Fixtures.repository.appendingPathComponent("docs/controls")
        let tiers = Dictionary(uniqueKeysWithValues: LibraryContracts.tiers.map { ($0.name, $0) })
        var wrong: [String] = []

        for file in try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        where file.hasSuffix(".md") && file != "README.md" {
            let entry = String(file.dropLast(3))
            let text = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
            var built: Set<String> = [entry]

            for source in Self.declaredIn(text) {
                built.formUnion(try Fixtures.nodeTypes(in: source))
            }

            let own = LibraryContracts.elements
                .filter { built.contains($0.nodeType.name) }
                .flatMap { $0.worn }

            for (heading, rows) in Self.sections(of: text) {
                let owners: [any Contract.Type]

                if heading == "## \(entry)'s own members" {
                    owners = own
                } else if heading.hasPrefix("## From ["),
                          let tier = tiers[String(heading.dropFirst("## From [".count).prefix { $0 != "]" })] {
                    owners = [tier]
                } else {
                    continue
                }

                for row in rows where !Self.declares(row, in: owners) {
                    wrong.append("\(entry) \(heading.dropFirst(3)): \(row.kind) `\(row.token)`")
                }
            }
        }

        for (name, tier) in tiers {
            let path = folder.appendingPathComponent("tiers/\(name).md")
            guard let text = try? String(contentsOf: path, encoding: .utf8) else { continue }

            for row in Self.sections(of: text).flatMap(\.rows) where !Self.declares(row, in: [tier]) {
                wrong.append("tiers/\(name): \(row.kind) `\(row.token)`")
            }
        }

        XCTAssertEqual(wrong, [], "a dictionary row no contract its entry describes declares")
    }

    // MARK: - Support

    /// One member row of the dictionary: its token and its kind.
    private struct Row {
        let token: String
        let kind: String
    }

    /// Whether a row is a member of one of the contracts, of the row's kind -
    /// a handler row an event, a property row a property.
    private static func declares(_ row: Row, in contracts: [any Contract.Type]) -> Bool {
        let kind: MemberFacts.Kind = row.kind == "handler" ? .event : .property

        return contracts.contains { contract in
            contract.members.contains { member in
                member.name == row.token && (member as? any DeclaredMember)?.facts.kind == kind
            }
        }
    }

    /// Every `## ` section of a dictionary file, with its member rows.
    private static func sections(of text: String) -> [(heading: String, rows: [Row])] {
        var result: [(heading: String, rows: [Row])] = []

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                result.append((line, []))
            } else if line.hasPrefix("| `"), !result.isEmpty {
                let cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                let token = cells[1].split(separator: "`").map(String.init)
                    .filter { !$0.contains("(") && !$0.contains(")") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    .last ?? cells[1]
                result[result.count - 1].rows.append(Row(token: token, kind: cells[2]))
            }
        }

        return result
    }

    /// The sources a dictionary file says its members are declared in, as
    /// paths under lib/StateUI/Sources.
    private static func declaredIn(_ text: String) -> [String] {
        let prefix = "lib/StateUI/Sources/"

        guard let line = text.components(separatedBy: "\n").first(where: { $0.hasPrefix("Declared in ") }) else {
            return []
        }

        return line.components(separatedBy: "`").filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }

    private static func platformContract() throws -> String {
        try String(contentsOf: Fixtures.repository.appendingPathComponent("docs/platform-contract.md"), encoding: .utf8)
    }

    /// The backticked names between a heading and the next heading.
    private static func listed(under heading: String, in document: String) -> Set<String> {
        guard let start = document.range(of: heading + "\n") else { return [] }

        let rest = document[start.upperBound...]
        let end = rest.range(of: "\n#")?.lowerBound ?? rest.endIndex

        return Set(rest[..<end].components(separatedBy: "`").enumerated()
            .filter { $0.offset % 2 == 1 }
            .map(\.element))
    }

    /// The backticked names in the table rows of one `## ` section.
    private static func backticked(inTableOf heading: String, in document: String) -> Set<String> {
        guard let start = document.range(of: heading + "\n") else { return [] }

        let rest = document[start.upperBound...]
        let end = rest.range(of: "\n## ")?.lowerBound ?? rest.endIndex
        var names: Set<String> = []

        for line in rest[..<end].split(separator: "\n") where line.hasPrefix("| ") && !line.hasPrefix("| ---") {
            let pieces = line.components(separatedBy: "`")

            for (offset, piece) in pieces.enumerated() where offset % 2 == 1 {
                names.insert(piece)
            }
        }

        return names
    }

    /// What one list has and the other lacks, each way, for a failure that
    /// names both.
    private static func difference(_ listed: Set<String>, _ declared: Set<String>) -> [String] {
        listed.subtracting(declared).sorted().map { "listed, not declared: \($0)" }
            + declared.subtracting(listed).sorted().map { "declared, not listed: \($0)" }
    }
}
