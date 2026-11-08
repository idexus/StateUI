// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A test writes a key as its name; the library makes a key only where it declares one, so it has no literal form.
// Design: docs/design/core/contracts.md#a-key-is-a-number

@_spi(Host) @testable import StateUI
import XCTest

extension Prop: ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(LibraryNames.token(name, .property)) }
}

extension Event: ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(LibraryNames.token(name, .event)) }
}

extension Act: ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(LibraryNames.token(name, .act)) }
}

/// The token a test's literal names: a library member's own name stands for its token - its owner's name, a dot,
/// and its own - and a name with its owner, or one no library member has, stands as written.
enum LibraryNames {
    /// The library's members of each kind, by their own names, each with the tokens of that name.
    private static let tokens: [MemberFacts.Kind: [String: [String]]] = {
        var tokens: [MemberFacts.Kind: [String: [String]]] = [:]
        for contract in LibraryContracts.all {
            for case let member as any DeclaredMember in contract.members {
                tokens[member.facts.kind, default: [:]][member.name, default: []].append(member.memberKey.name)
            }
        }
        return tokens
    }()

    /// The token `name` stands for among the library's members of `kind`; two of that name fail the test until it
    /// says which.
    static func token(_ name: String, _ kind: MemberFacts.Kind) -> String {
        guard !name.contains("."), let found = tokens[kind]?[name] else { return name }
        guard found.count == 1 else {
            XCTFail("`\(name)` names \(found.sorted().joined(separator: " and ")): write one")
            return name
        }
        return found[0]
    }
}

/// The key a member crosses under, by name - nil for a member that is no property, event or act.
func keyName(of member: any ContractMember) -> String? {
    (member as? any KeyedMember)?.memberKey.name
}
