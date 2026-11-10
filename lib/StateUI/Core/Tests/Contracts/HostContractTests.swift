// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The native-host contract is closed over StateUI's built-in vocabulary even
/// though applications remain free to declare their own contracts.
@MainActor
final class HostContractTests: XCTestCase {
    func testEveryBuiltInControlPropertyAndEventHasOneOwner() throws {
        let source = try SourceTree.text(in: "Tokens.swift")

        assertCoverage(
            classified: Set(LibraryContracts.elements.map { $0.nodeType.name }),
            declared: declaredNames(of: "NodeType", in: source),
            vocabulary: "NodeType")
        assertCoverage(
            classified: Self.names(of: .property),
            declared: declaredNames(of: "Prop", in: source),
            vocabulary: "Prop")
        assertCoverage(
            classified: Self.names(of: .event),
            declared: declaredNames(of: "Event", in: source),
            vocabulary: "Event")
    }

    func testWhatStateUIDecidesBelongsToStateUI() {
        for type in [
            NodeType.ellipse, .grid,
            .line, .path, .polygon, .polyline,
            .rectangle,
        ] {
            XCTAssertEqual(Self.layer(of: type), .stateUI)
        }
        XCTAssertEqual(Self.layer(of: .checkBox), .adaptive, "a toolkit's own box where it has one")

        for property in [
            Prop.columns, .gridColumn, .gridColumnSpan, .gridRow,
            .gridRowSpan, .rows,
        ] {
            XCTAssertEqual(Self.layer(of: property), .stateUI)
        }
    }

    func testProtocolNodesRemainStructural() {
        for type in [
            NodeType.application, .scene, .window, .overlay,
        ] {
            XCTAssertEqual(Self.layer(of: type), .structure)
        }
    }

    func testProviderSurfaceDoesNotBecomeABaseHostRequirement() {
        XCTAssertEqual(Self.layer(of: NodeType.map), .provider)
        XCTAssertEqual(Self.layer(of: NodeType.marker), .provider)
        XCTAssertEqual(Self.layer(of: MarkerContract.kind.token), .provider)
        XCTAssertEqual(Self.layer(of: Prop.region), .provider)
        XCTAssertEqual(Self.layer(of: Event.locationTapped), .provider)
    }

    func testPlatformContractNamesEveryBuiltInTokenAndTargetHost() throws {
        let document = try String(
            contentsOf: SourceTree.repository.appendingPathComponent("docs/platform-contract.md"),
            encoding: .utf8)
        let statusRows = document
            .components(separatedBy: "## Complete host vocabulary")[0]
            .split(separator: "\n")
            .filter { $0.hasPrefix("| ") }
            .joined(separator: "\n")

        assertDocumented(
            LibraryContracts.elements.map { $0.nodeType.name },
            vocabulary: "control",
            in: statusRows)
        assertDocumented(
            Self.names(of: .property).sorted(),
            vocabulary: "property",
            in: statusRows)
        assertDocumented(
            Self.names(of: .event).sorted(),
            vocabulary: "event",
            in: statusRows)

        for host in ["AppKit", "UIKit", "Android Views", "WinUI 3", "GTK 4", "Web"] {
            XCTAssertTrue(document.contains(host), "platform contract does not name \(host)")
        }
        XCTAssertTrue(document.contains("| ✅ | "), "platform contract does not define completion in its legend")
    }

    /// The names of the library's members of `kind` that are each one member's: a name two contracts declare has
    /// no token of its own in Tokens.swift - each place reading it names its member.
    private static func names(of kind: MemberFacts.Kind) -> Set<String> {
        let names = LibraryContracts.all.flatMap { contract in
            contract.members.compactMap { member in
                (member as? any DeclaredMember)?.facts.kind == kind ? member.name : nil
            }
        }
        return Set(Dictionary(grouping: names) { $0 }.filter { $1.count == 1 }.keys)
    }

    /// The layer an element's contract declares, by its node type - nil for a
    /// type no library contract declares.
    private static func layer(of type: NodeType) -> ElementLayer? {
        LibraryContracts.elements.first { $0.nodeType == type }?.layer
    }

    /// The layer the property of that key declares.
    private static func layer(of property: Prop) -> ElementLayer? {
        facts(of: property.key, kind: .property)?.layer
    }

    /// The layer the event of that key declares.
    private static func layer(of event: Event) -> ElementLayer? {
        facts(of: event.key, kind: .event)?.layer
    }

    /// What the member of a key and a kind says of itself.
    private static func facts(of key: KeyName, kind: MemberFacts.Kind) -> MemberFacts? {
        for contract in LibraryContracts.all {
            for case let member as any DeclaredMember in contract.members
            where member.memberKey == key && member.facts.kind == kind {
                return member.facts
            }
        }

        return nil
    }


    private func declaredNames(of vocabulary: String, in source: String) -> Set<String> {
        SourceTree.tokenNames(of: vocabulary, in: source)
    }

    private func assertCoverage(
        classified: Set<String>,
        declared: Set<String>,
        vocabulary: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            classified,
            declared,
            """
            \(vocabulary) ownership is incomplete.
            Unclassified: \(declared.subtracting(classified).sorted())
            Undeclared: \(classified.subtracting(declared).sorted())
            """,
            file: file,
            line: line)
    }

    private func assertDocumented(
        _ names: some Sequence<String>,
        vocabulary: String,
        in document: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let missing = names.filter { !document.contains("`\($0)`") }.sorted()
        XCTAssertTrue(
            missing.isEmpty,
            "platform contract is missing \(vocabulary) tokens: \(missing)",
            file: file,
            line: line)
    }
}
