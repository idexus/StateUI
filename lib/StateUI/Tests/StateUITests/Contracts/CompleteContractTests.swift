// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The whole contract, against everything that names the library's vocabulary:
// every node type is one element's, every act a member of exactly one
// contract; every name the platform contract's tables use is in the contract;
// every member a source writes or hears is a member, of that kind, of a
// contract the source describes.

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
    func testEveryNodeTypeIsExactlyOneElementsContract() throws {
        var contracts: [String: [String]] = [:]

        for element in LibraryContracts.elements {
            contracts[element.nodeType.name, default: []].append(String(describing: element))
        }

        let types = try Fixtures.tokenNames(of: "NodeType")
        XCTAssertEqual(types.subtracting(contracts.keys).sorted(), [], "a node type with no contract")
        XCTAssertEqual(Set(contracts.keys).subtracting(types).sorted(), [], "a contract for no node type")
        XCTAssertEqual(contracts.filter { $0.value.count > 1 }.keys.sorted(), [], "a node type with two contracts")
    }

    /// Every node the library builds, it builds through a contract -
    /// `Node(contract:)` - so the node type is the contract's and every value
    /// on it a member's. Two are built by type, each for its reason: the
    /// differ's placeholder for a composed view not built yet, which never
    /// crosses and so has no contract, and a style's node, which takes the type
    /// its target's node already has.
    ///
    /// Read across lines: a construction wrapped after `Node(` is the same
    /// construction, and a scan reading line by line walks past it.
    func testEveryNodeIsBuiltThroughItsContract() throws {
        let allowed: [(path: String, construction: String)] = [
            ("Stateful.swift", "Node(type: .composed)"),
            ("Style.swift", "Node(type: Target().node.type)"),
        ]
        var byType: [String] = []

        for source in try Fixtures.allSources() {
            let text = source.text
            var searched = text.startIndex..<text.endIndex

            while let found = text.range(of: #"Node\(\s*type:"#, options: .regularExpression, range: searched) {
                searched = found.upperBound..<text.endIndex

                let lineStart = text[..<found.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) }
                    ?? text.startIndex
                let lineEnd = text[found.lowerBound...].firstIndex(of: "\n") ?? text.endIndex
                let line = text[lineStart..<lineEnd].trimmingCharacters(in: .whitespaces)

                if line.hasPrefix("//") { continue }
                if allowed.contains(where: { Fixtures.name(of: source.path) == $0.path && text[found.lowerBound...].hasPrefix($0.construction) }) {
                    continue
                }

                let number = text[..<found.lowerBound].filter { $0 == "\n" }.count + 1
                byType.append("\(source.path):\(number)  \(line.prefix(70))")
            }
        }

        for exception in allowed {
            XCTAssertTrue(try Fixtures.text(in: exception.path).contains(exception.construction),
                          "\(exception.path) no longer builds \(exception.construction)")
        }

        XCTAssertEqual(byType, [], "a node built by type rather than through its contract")
    }

    /// Every act the library declares is a member of exactly one contract,
    /// and every act member is one the library declares.
    func testEveryActIsAMemberOfExactlyOneContract() throws {
        let acts = try Fixtures.tokenNames(of: "Act")
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

    /// Every name a row of the platform contract's tables uses is in the
    /// contract - a node type, a member, a handler's `on…` spelling of an
    /// event member - or one of the core view members the hand-written table
    /// names, each listed here with what it is.
    func testEveryNameThePlatformContractsTablesUseIsInTheContract() throws {
        let document = try Self.platformContract()
        let sections = ["## Control creation", "## Host acts", "## Shared view members", "## Contract members"]
        let coreAPI: Set<String> = [
            // Identity, aiming and reactions every element has, which no host realizes.
            "id", "aim", "onChanged", "samples", "engine",
            // Motion, which the differ writes beside the values it moves.
            "motion", "MotionValues", "MotionLanes",
            // The focus feed, a state the element's focus event keeps.
            "isFocused",
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
        where source.path.hasPrefix("Views/") || Self.describing[Fixtures.name(of: source.path)] != nil {
            let properties = Fixtures.propertyKeys(inSource: source.text)
            let events = Fixtures.handlerKeys(inSource: source.text)

            guard !properties.isEmpty || !events.isEmpty else { continue }

            let described = Fixtures.nodeTypes(inSource: source.text)
                .union(Self.describing[Fixtures.name(of: source.path)] ?? [])
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

    /// Every element `describing` lists for a source is one the source cannot
    /// say: an element it builds or extends is read from its text.
    func testDescribingListsOnlyWhatASourceCannotSay() throws {
        var said: [String] = []

        for (path, elements) in Self.describing.sorted(by: { $0.key < $1.key }) {
            let text = try Fixtures.text(in: path)
            let read = Fixtures.nodeTypes(inSource: text).union(Self.extended(in: text))

            for element in elements where read.contains(element) {
                said.append("\(path): \(element)")
            }
        }

        XCTAssertEqual(said, [], "an element listed for a source that builds or extends it")
    }

    // MARK: - Support

    /// The sources that write for an element they neither build nor extend:
    /// the window's properties, which the scenes and the window's session
    /// write, the page's, which its session keeps, the placed layout's, a
    /// composition over an `AbsoluteLayout` placing its children, and every
    /// visual element's style key, which the style sheet reads and takes off.
    private static let describing: [String: [String]] = [
        "SceneElement.swift": ["Window"],
        "WindowSession.swift": ["Window"],
        "PageSession.swift": ["Page"],
        "PlacedLayout.swift": ["AbsoluteLayout"],
        "StyleSheet.swift": ["VisualElement"],
    ]

    /// The contracts a source names by its protocols and extensions -
    /// `extension FontElement`, `public protocol ViewProperties`, a tier's
    /// `…Properties` spelling read as the tier.
    private static func extended(in source: String) -> Set<String> {
        let regex = try! NSRegularExpression(pattern: #"^(?:public )?(?:protocol|extension) (\w+)"#,
                                             options: .anchorsMatchLines)
        var names: Set<String> = []

        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            let name = String(source[Range(match.range(at: 1), in: source)!])
            names.insert(name.hasSuffix("Properties") ? String(name.dropLast("Properties".count)) : name)
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
}
