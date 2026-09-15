// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The whole contract, against everything that names the library's vocabulary:
// every node type is one element's, every property and event of the ownership
// table a member, every act a member of exactly one contract; the platform
// contract's vocabulary is the contracts' own, and every name its tables use is
// in the contract; every member a source writes or hears is a member, of that
// kind, of a contract the source describes.

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

    // MARK: - The sources

    /// Every member a view's source writes or hears is a member, of that kind,
    /// of a contract the source describes or of a tier that contract wears: an
    /// element's file writes its own contract's members and its tiers', a
    /// tier's file its tier's. A source describes the elements whose node
    /// types it builds and the contracts its protocols and extensions name;
    /// the few writing for an element they neither build nor extend are in
    /// `describing`.
    func testEverySourceWritesOnlyMembersOfWhatItDescribes() throws {
        let contracts = Dictionary(LibraryContracts.all.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var wrong: [String] = []
        var read = 0

        for source in try Fixtures.allSources()
        where source.path.hasPrefix("Views/") || Self.describing[source.path] != nil {
            let properties = Fixtures.propertyKeys(inSource: source.text)
            let events = Fixtures.handlerKeys(inSource: source.text)

            guard !properties.isEmpty || !events.isEmpty else { continue }

            let described = Fixtures.nodeTypes(inSource: source.text)
                .union(Self.describing[source.path] ?? [])
                .union(Self.extended(in: source.text))
            let owners = described.compactMap { contracts[$0] }.flatMap { $0.worn }

            read += 1

            guard !owners.isEmpty else {
                wrong.append("\(source.path): describes no contract")
                continue
            }

            for name in properties.sorted() where !Self.declares(name, .property, in: owners) {
                wrong.append("\(source.path): property `\(name)`")
            }

            for name in events.sorted() where !Self.declares(name, .event, in: owners) {
                wrong.append("\(source.path): event `\(name)`")
            }
        }

        XCTAssertGreaterThan(read, 30, "the scan read almost nothing")
        XCTAssertEqual(wrong, [], "a member a source writes that no contract it describes declares")
    }

    // MARK: - Support

    /// The sources that write for an element they neither build by its node
    /// type nor extend: the scene's handlers and the window's and the page's
    /// properties, written where a session keeps them, and the placed layout,
    /// a composition over an `AbsoluteLayout` placing its children.
    private static let describing: [String: [String]] = [
        "Core/Scenes.swift": ["Scene", "Window"],
        "Types/HostEnvironment.swift": ["Window"],
        "Types/PageSession.swift": ["Page"],
        "Views/Application.swift": ["Window", "Page"],
        "Views/PlacedLayout.swift": ["AbsoluteLayout"],
    ]

    /// The contracts a source names by its protocols and extensions -
    /// `extension FontElement`, `public protocol ViewProperties`, a tier's
    /// `…Properties` spelling read as the tier - and by the contract it builds
    /// a node from, `Node(contract: LabelContract.self)`.
    private static func extended(in source: String) -> Set<String> {
        var names: Set<String> = []

        for pattern in [#"^(?:public )?(?:protocol|extension) (\w+)"#, #"Node\(contract:\s*(\w+)Contract\.self"#] {
            let regex = try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

            for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                let name = String(source[Range(match.range(at: 1), in: source)!])
                names.insert(name.hasSuffix("Properties") ? String(name.dropLast("Properties".count)) : name)
            }
        }

        return names
    }

    /// Whether one of the contracts declares a member of that name and kind.
    private static func declares(_ name: String, _ kind: MemberFacts.Kind, in contracts: [any Contract.Type]) -> Bool {
        contracts.contains { contract in
            contract.members.contains { member in
                member.name == name && (member as? any DeclaredMember)?.facts.kind == kind
            }
        }
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
