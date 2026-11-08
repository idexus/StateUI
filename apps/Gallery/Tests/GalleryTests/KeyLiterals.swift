// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A test writes a key as its name; the library makes a key only where it declares one, so it has no literal form.

@_spi(Host) import StateUI
import XCTest

extension Prop: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(LibraryNames.token(name)) }
}

extension Event: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(LibraryNames.token(name)) }
}

extension Act: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(LibraryNames.token(name)) }
}

/// The token a test's literal names: a library member's own name stands for its token - its contract's name, a
/// dot, and its own - and a name with its owner, or one no library member has, stands as written. The library
/// gives no name to two kinds of member, so a name is looked up among all of them.
enum LibraryNames {
    /// The library's members by their own names, each with the tokens of that name.
    private static let tokens: [String: [String]] = ((LibraryContracts.tiers as [any Contract.Type])
        + LibraryContracts.elements.map { $0 as any Contract.Type }).reduce(into: [:]) { tokens, contract in
        for member in contract.members { tokens[member.name, default: []].append("\(contract.name).\(member.name)") }
    }

    /// The token `name` stands for; two of that name fail the test until it says which.
    static func token(_ name: String) -> String {
        guard !name.contains("."), let found = tokens[name] else { return name }
        guard found.count == 1 else {
            XCTFail("`\(name)` names \(found.sorted().joined(separator: " and ")): write one")
            return name
        }
        return found[0]
    }
}
