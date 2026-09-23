// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The library's contracts, held to what they stand beside: the members of one
// name share their layer, travel, clearing and motion, which the differ and the
// hosts read by the name; every member's name is a token the library declares
// and the name of the static member holding it; every declared member is on its
// contract's list; and no contract wears two members of one name.

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

    // MARK: - The facts

    /// The members of one name say the same of their layer, travel, clearing
    /// and motion: the differ and the hosts hold a token, which is a name, and
    /// read what it says by the name - two members of one name that disagreed
    /// would each be half wrong.
    func testTheMembersOfOneNameShareTheirFacts() {
        var first: [String: Declared] = [:]
        var wrong: [String] = []

        for member in declared where member.facts.kind != .act {
            let key = "\(member.facts.kind) \(member.name)"
            guard let earlier = first[key] else {
                first[key] = member
                continue
            }

            if (earlier.facts.layer, earlier.facts.travels, earlier.facts.cleared, earlier.facts.moves)
                != (member.facts.layer, member.facts.travels, member.facts.cleared, member.facts.moves) {
                wrong.append("\(member.contract).\(member.name) differs from \(earlier.contract)'s")
            }
        }

        XCTAssertEqual(wrong, [])
    }

    /// A token's facts are its members': what the differ reads by a name is
    /// what the contracts declare under it - and a name no contract declares,
    /// an application's own, travels, is cleared and says nothing of motion.
    func testATokensFactsAreItsMembers() {
        var wrong: [String] = []

        for member in declared where member.facts.kind == .property {
            let read = Prop(member.name).facts
            if (read.travels, read.cleared, read.moves)
                != (member.facts.travels, member.facts.cleared, member.facts.moves) {
                wrong.append("\(member.contract).\(member.name)")
            }
        }

        XCTAssertEqual(wrong, [])
        XCTAssertEqual(Prop("Test.Unknown").facts, .undeclared)
    }

    // MARK: - The names

    /// A member crosses under its name, so a library member's name is a token
    /// the library declares in Tokens.swift.
    func testEveryMemberIsATokenTheLibraryDeclares() throws {
        let tokens: [MemberFacts.Kind: Set<String>] = [
            .property: try Fixtures.tokenNames(of: "Prop"),
            .event: try Fixtures.tokenNames(of: "Event"),
            .act: try Fixtures.tokenNames(of: "Act"),
        ]

        let stranded = declared.filter { tokens[$0.facts.kind]?.contains($0.name) != true }

        XCTAssertEqual(stranded.map { "\($0.contract).\($0.name)" }, [])
    }

    /// A member's own name is the name of the static member holding it:
    /// `static let fontSize = ElementProperty<Self, Double>("fontSize", …)`.
    func testAMembersNameIsTheNameOfItsStaticMember() throws {
        var wrong: [String] = []
        var read = 0

        for file in try Self.contractFiles() {
            let declarations = Self.declarations(in: file.text)

            read += declarations.count

            for (member, spelling) in declarations where member != spelling {
                wrong.append("\(file.path): \(member) is written \"\(spelling)\"")
            }
        }

        XCTAssertGreaterThan(read, 210, "the scan read almost nothing")
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

        let files = try Self.contractFiles()

        XCTAssertGreaterThan(files.count, 55, "the scan read almost nothing")

        for file in files {
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
