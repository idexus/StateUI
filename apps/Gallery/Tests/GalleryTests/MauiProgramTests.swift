// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The Gallery's C# registrations and its Swift contracts name the same things.
//
// A contract says what the Swift half writes and hears; MauiProgram.cs says
// what the C# half registers. A name on one side and not the other compiles on
// both and does nothing: a property no registration reads, an event nobody
// raises, an act that answers "unknown act". So the two are read against each
// other here, the way WireFormatTests holds the library's tokens against the
// host's mirror.

#if MAUI
import Foundation
import XCTest
@testable import GalleryUI
@_spi(Host) @testable import StateUI

final class MauiProgramTests: XCTestCase {
    /// The Gallery's element contracts. A registration beside none of them
    /// fails below, so the list cannot fall behind MauiProgram.
    static let elements: [any ElementContract.Type] = [
        TrafficLightContract.self, RatingBarContract.self, BadgeContract.self,
    ]

    /// Every contract the Gallery declares: its elements', and the tier the
    /// application wears.
    private static let contracts: [any Contract.Type] =
        elements.map { $0 as any Contract.Type } + [GalleryContract.self]

    /// The act the Gallery declares and registers nowhere, on purpose: the
    /// "Calling C#" sample calls it to show what a missing registration does.
    private static let unregistered: Set<String> = ["Gallery.Nobody"]

    /// Every control MauiProgram registers is one of the Gallery's elements,
    /// and every element is registered.
    func testEveryRegisteredControlIsAnElementOfTheGallerysContracts() throws {
        XCTAssertEqual(
            try Self.registered(#"StateUIControls\.Add\("([^"]+)""#),
            Set(Self.elements.map { $0.nodeType.name }))
    }

    /// Every act a Gallery contract declares has its performer - the one left
    /// out on purpose apart - and no performer answers a name no contract
    /// declares.
    func testEveryDeclaredActIsRegistered() throws {
        XCTAssertEqual(
            try Self.registered(#"StateUIActs\.Add\("([^"]+)""#),
            Self.names(of: .act).subtracting(Self.unregistered))
    }

    /// What MauiProgram raises by name is the application tier's events, and
    /// what a registered control raises through its `raise` is its element's.
    func testEveryEventIsRaisedWhereItsContractSays() throws {
        XCTAssertEqual(
            try Self.registered(#"StateUIEvents\.Raise\("([^"]+)""#),
            Self.names(of: .event, in: [GalleryContract.self]))
        XCTAssertEqual(
            try Self.registered(#"raise\(\w+, "([^"]+)""#),
            Self.names(of: .event, in: Self.elements.map { $0 as any Contract.Type }))
    }

    /// Every property a registration reads or declares is a member of the
    /// Gallery's elements, and every such member is read.
    func testEveryPropertyARegistrationReadsIsAMember() throws {
        XCTAssertEqual(
            try Self.registered(#"(?:Get\w+\(|\[)"([a-z][A-Za-z0-9]*)"(?:\)|\] =)"#),
            Self.names(of: .property))
    }

    // MARK: - Reading both sides

    /// The names MauiProgram.cs hands a registry, by the pattern's first
    /// group.
    private static func registered(_ pattern: String) throws -> Set<String> {
        let text = try String(contentsOf: program, encoding: .utf8)
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)

        return Set(expression.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        })
    }

    /// The names the Gallery's contracts declare their own members of one
    /// kind under.
    private static func names(
        of kind: MemberFacts.Kind,
        in list: [any Contract.Type] = contracts
    ) -> Set<String> {
        Set(list.flatMap { contract in
            contract.members.compactMap { member in
                (member as? any DeclaredMember)?.facts.kind == kind ? member.name : nil
            }
        })
    }

    /// Platforms/Maui/Host/MauiProgram.cs, beside these tests.
    private static var program: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // GalleryTests
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // Gallery
            .appendingPathComponent("Platforms/Maui/Host/MauiProgram.cs")
    }
}
#endif
