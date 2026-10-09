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

    func testDerivedLayoutsAndControlsBelongToStateUI() {
        for type in [
            NodeType.checkBox, .ellipse, .grid,
            .line, .path, .polygon, .polyline, .radioButton,
            .rectangle,
        ] {
            XCTAssertEqual(Self.layer(of: type), .stateUI)
        }

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
        XCTAssertEqual(Self.layer(of: Prop.mapType), .provider)
        XCTAssertEqual(Self.layer(of: Prop.region), .provider)
        XCTAssertEqual(Self.layer(of: Event.mapClicked), .provider)
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

    /// The names the library's contracts declare members of one kind under.
    private static func names(of kind: MemberFacts.Kind) -> Set<String> {
        Set(LibraryContracts.all.flatMap { contract in
            contract.members.compactMap { member in
                (member as? any DeclaredMember)?.facts.kind == kind ? member.name : nil
            }
        })
    }

    /// The layer an element's contract declares, by its node type - nil for a
    /// type no library contract declares.
    private static func layer(of type: NodeType) -> ElementLayer? {
        LibraryContracts.elements.first { $0.nodeType == type }?.layer
    }

    /// The layer the properties of one name declare - the members of one name
    /// share it (`LibraryContractTests`).
    private static func layer(of property: Prop) -> ElementLayer? {
        facts(of: property.name, kind: .property)?.layer
    }

    /// The layer the events of one name declare.
    private static func layer(of event: Event) -> ElementLayer? {
        facts(of: event.name, kind: .event)?.layer
    }

    /// What the first member of a name and a kind says of itself.
    private static func facts(of name: String, kind: MemberFacts.Kind) -> MemberFacts? {
        for contract in LibraryContracts.all {
            for member in contract.members where member.name == name {
                if let facts = (member as? any DeclaredMember)?.facts, facts.kind == kind {
                    return facts
                }
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
