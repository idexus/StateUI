// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The library's contracts, held to what they stand beside until the old tables
// go: every member's layer, travel, clearing and motion group equal the
// ownership table and the three property sets; every member's name is a token
// the library declares and the name of the static member holding it; every
// declared member is on its contract's list; and no contract wears two members
// of one name.

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

final class LibraryContractTests: XCTestCase {
    /// One library member, with the contract it is declared in.
    private struct Declared {
        let contract: String
        let name: String
        let facts: MemberFacts
    }

    /// Every member of every library contract.
    private var declared: [Declared] {
        LibraryContracts.all.flatMap { contract in
            contract.members.map { member in
                Declared(
                    contract: contract.name,
                    name: member.name,
                    facts: (member as? any DeclaredMember)?.facts
                        ?? MemberFacts(kind: .act, layer: nil, travels: true, cleared: true, moves: []))
            }
        }
    }

    // MARK: - The facts equal the tables

    /// A property's layer is the ownership table's owner, it travels unless
    /// `Prop.unmoved` holds it, it is cleared unless `Prop.notCleared` holds
    /// it, and its motion group is `Prop.moving`'s.
    func testEveryPropertysFactsAreTheTablesItStandsBeside() {
        var wrong: [String] = []

        for member in declared where member.facts.kind == .property {
            let prop = Prop(member.name)
            let path = "\(member.contract).\(member.name)"

            let owner = HostContract.properties[prop].map(Self.layer(of:))
            if owner != member.facts.layer {
                wrong.append("\(path): layer \(String(describing: member.facts.layer)), "
                    + "the ownership table says \(String(describing: owner))")
            }
            if member.facts.travels == Prop.unmoved.contains(prop) {
                wrong.append("\(path): travels \(member.facts.travels), Prop.unmoved says otherwise")
            }
            if member.facts.cleared == Prop.notCleared.contains(prop) {
                wrong.append("\(path): cleared \(member.facts.cleared), Prop.notCleared says otherwise")
            }
            if member.facts.moves != prop.moving {
                wrong.append("\(path): moves \(member.facts.moves.rawValue), Prop.moving says "
                    + "\(prop.moving.rawValue)")
            }
        }

        XCTAssertEqual(wrong, [])
    }

    /// An event's layer is the ownership table's owner.
    func testEveryEventsLayerIsTheOwnershipTables() {
        var wrong: [String] = []

        for member in declared where member.facts.kind == .event {
            let owner = HostContract.events[Event(member.name)].map(Self.layer(of:))
            if owner != member.facts.layer {
                wrong.append("\(member.contract).\(member.name): layer "
                    + "\(String(describing: member.facts.layer)), the ownership table says "
                    + "\(String(describing: owner))")
            }
        }

        XCTAssertEqual(wrong, [])
    }

    // MARK: - The names

    /// A member crosses under its name, so a library member's name is a token
    /// the library declares - and only a property or an event of the
    /// ownership table, or an act of Core/Tokens.swift, is one.
    func testEveryMemberIsATokenTheLibraryDeclares() {
        let stranded = declared.filter { member in
            switch member.facts.kind {
            case .property: HostContract.properties[Prop(member.name)] == nil
            case .event: HostContract.events[Event(member.name)] == nil
            case .act: false
            }
        }

        XCTAssertEqual(stranded.map { "\($0.contract).\($0.name)" }, [])
    }

    /// A member's own name is the name of the static member holding it:
    /// `static let fontSize = ElementProperty<Self, Double>("fontSize", …)`.
    func testAMembersNameIsTheNameOfItsStaticMember() throws {
        var wrong: [String] = []

        for file in try Self.contractFiles() {
            for (member, spelling) in Self.declarations(in: file.text) where member != spelling {
                wrong.append("\(file.path): \(member) is written \"\(spelling)\"")
            }
        }

        XCTAssertEqual(wrong, [])
    }

    /// An element contract's node type is its own name - `LabelContract`
    /// declares "Label" - so the name a host resolves is the contract's, and
    /// nothing is left to look up.
    func testEveryNodeTypeIsItsContractsName() {
        let wrong = LibraryContracts.elements.compactMap { contract -> String? in
            let name = String(describing: contract)
            let expected = String(name.dropLast("Contract".count))
            return contract.nodeType.name == expected ? nil : "\(name) declares \"\(contract.nodeType.name)\""
        }

        XCTAssertEqual(wrong, [])
    }

    /// Every member a contract declares is on its `members` list, and the
    /// list names nothing else: the list is what the dictionary shows and
    /// what a host is held to.
    func testEveryDeclaredMemberIsOnItsContractsList() throws {
        var wrong: [String] = []

        for file in try Self.contractFiles() {
            let declared = Set(Self.declarations(in: file.text).map(\.member))
            let listed = Set(Self.listed(in: file.text))

            for missing in declared.subtracting(listed).sorted() {
                wrong.append("\(file.path): \(missing) is declared and not listed")
            }
            for stranger in listed.subtracting(declared).sorted() {
                wrong.append("\(file.path): \(stranger) is listed and not declared")
            }
        }

        XCTAssertEqual(wrong, [])
    }

    /// No contract wears two members of one name: a node's properties are one
    /// map, so two would write each other's key.
    func testNoContractWearsTwoMembersOfOneName() {
        var twice: [String] = []

        for contract in LibraryContracts.all {
            var seen: [String: String] = [:]

            for worn in contract.worn {
                for member in worn.members {
                    if let first = seen[member.name] {
                        twice.append("\(contract.name) wears \(member.name) from \(first) and \(worn.name)")
                    }
                    seen[member.name] = worn.name
                }
            }
        }

        XCTAssertEqual(twice, [])
    }

    /// A tier wears the tiers its Swift protocol refines, so an element
    /// listing the protocol-level tier gets the chain: View wears
    /// VisualElement, which wears PropertyContainer.
    func testATierWearsTheChainItsProtocolRefines() {
        XCTAssertEqual(ViewContract.worn.map { $0.name }, ["View", "VisualElement", "PropertyContainer"])
        XCTAssertEqual(StackBaseContract.worn.map { $0.name }, [
            "StackBase", "Layout", "View", "VisualElement", "PropertyContainer", "PaddingElement",
        ])
    }

    // MARK: - Support

    /// The ownership table's word, as the contract's.
    private static func layer(of owner: HostPropertyOwner) -> ElementLayer {
        switch owner {
        case .native: .native
        case .adaptive: .adaptive
        case .stateUI: .stateUI
        case .structure: .structure
        case .provider: .provider
        }
    }

    /// The same, for an event's owner.
    private static func layer(of owner: HostEventOwner) -> ElementLayer {
        switch owner {
        case .native: .native
        case .adaptive: .adaptive
        case .stateUI: .stateUI
        case .provider: .provider
        }
    }

    /// Every source under `Sources/Contracts/` that declares members.
    private static func contractFiles() throws -> [(path: String, text: String)] {
        try Fixtures.allSources().filter {
            $0.path.hasPrefix("Contracts/") && $0.text.contains("public static let members")
        }
    }

    /// Each member a file declares, with the name written in its initializer:
    /// `static let NAME = Element…<…>(` and then the first string literal.
    private static func declarations(in text: String) -> [(member: String, spelling: String)] {
        let pattern = #"static let (\w+) = Element(?:Property|Event|Act)<[^>]*>\(\s*"(\w+(?:\.\w+)*)""#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)

        return regex.matches(in: text, range: range).map { match in
            (member: String(text[Range(match.range(at: 1), in: text)!]),
             spelling: String(text[Range(match.range(at: 2), in: text)!]))
        }
    }

    /// The names a file's `members` list holds.
    private static func listed(in text: String) -> [String] {
        guard let start = text.range(of: "public static let members: [any ContractMember] = [") else {
            return []
        }

        let rest = text[start.upperBound...]
        guard let end = rest.firstIndex(of: "]") else { return [] }

        return rest[..<end]
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map(String.init)
    }
}
