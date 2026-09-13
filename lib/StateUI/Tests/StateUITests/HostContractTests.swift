// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The native-host contract is closed over StateUI's built-in vocabulary even
/// though applications remain free to add their own tokens.
final class HostContractTests: XCTestCase {
    func testEveryBuiltInControlPropertyAndEventHasOneOwner() throws {
        let source = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)

        assertCoverage(
            classified: Set(HostContract.controls.keys.map(\.name)),
            declared: declaredNames(of: "NodeType", in: source),
            vocabulary: "NodeType")
        assertCoverage(
            classified: Set(HostContract.properties.keys.map(\.name)),
            declared: declaredNames(of: "Prop", in: source),
            vocabulary: "Prop")
        assertCoverage(
            classified: Set(HostContract.events.keys.map(\.name)),
            declared: declaredNames(of: "Event", in: source),
            vocabulary: "Event")
    }

    /// Page presentation, safe-area layout, backdrop composition, focus
    /// dismissal and navigation-title composition are expressed by their
    /// dedicated StateUI structures. They do not create a second, page-only
    /// vocabulary for capabilities that native hosts do not share.
    func testContentPageVocabularyContainsOnlySharedCapabilities() throws {
        let source = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
        let properties = declaredNames(of: "Prop", in: source)
        let pageOnlyAlternatives: Set<String> = [
            "backgroundImageSource",
            "hideSoftInputOnTapped",
            "modalPresentationStyle",
            "navigationPageIconColor",
            "navigationPageTitleIconImageSource",
            "useSafeArea",
        ]

        XCTAssertTrue(
            properties.isDisjoint(with: pageOnlyAlternatives),
            "page-only alternatives remain in the host contract: "
                + properties.intersection(pageOnlyAlternatives).sorted().joined(separator: ", "))
    }

    /// Stack names stay identical from application source through the typed
    /// host boundary. There is no second layout-shaped spelling to translate
    /// or preserve.
    func testStackVocabularyUsesThePublicStateUISpellings() throws {
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
        let stackSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Views/StackLayouts.swift"),
            encoding: .utf8)
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let formerNames = ["VerticalStackLayout", "HorizontalStackLayout"]

        XCTAssertTrue(controls.isSuperset(of: ["VStack", "HStack"]))
        XCTAssertTrue(
            controls.isDisjoint(with: Set(formerNames)),
            "legacy stack names remain in the host contract")
        for name in formerNames {
            XCTAssertFalse(stackSource.contains(name), "\(name) remains in the public API")
        }
    }

    func testDerivedLayoutsAndControlsBelongToStateUI() {
        for type in [
            NodeType.checkBox, .ellipse, .grid, .imageButton,
            .indicatorView, .line, .path, .polygon, .polyline, .radioButton,
            .rectangle, .refreshView, .roundRectangle, .swipeView,
        ] {
            XCTAssertEqual(HostContract.controls[type], .stateUI)
        }

        for property in [
            Prop.columnDefinitions, .gridColumn, .gridColumnSpan, .gridRow,
            .gridRowSpan, .rowDefinitions,
        ] {
            XCTAssertEqual(HostContract.properties[property], .stateUI)
        }
    }

    func testProtocolNodesRemainStructural() {
        for type in [
            NodeType.application, .scene, .window, .overlay, .swipeItem,
        ] {
            XCTAssertEqual(HostContract.controls[type], .structure)
        }
    }

    func testProviderSurfaceDoesNotBecomeABaseHostRequirement() {
        XCTAssertEqual(HostContract.controls[.map], .provider)
        XCTAssertEqual(HostContract.controls[.pin], .provider)
        XCTAssertEqual(HostContract.properties[.mapType], .provider)
        XCTAssertEqual(HostContract.properties[.region], .provider)
        XCTAssertEqual(HostContract.events[.mapClicked], .provider)
    }

    func testPlatformContractNamesEveryBuiltInTokenAndTargetHost() throws {
        let document = try String(
            contentsOf: Fixtures.repository.appendingPathComponent("docs/platform-contract.md"),
            encoding: .utf8)
        let statusRows = document
            .components(separatedBy: "## Complete host vocabulary")[0]
            .split(separator: "\n")
            .filter { $0.hasPrefix("| ") }
            .joined(separator: "\n")

        assertDocumented(
            HostContract.controls.keys.map(\.name),
            vocabulary: "control",
            in: statusRows)
        assertDocumented(
            HostContract.properties.keys.map(\.name),
            vocabulary: "property",
            in: statusRows)
        assertDocumented(
            HostContract.events.keys.map(\.name),
            vocabulary: "event",
            in: statusRows)

        for host in ["AppKit", "UIKit", "GTK 4", "Android Views", "WinUI 3", "Web"] {
            XCTAssertTrue(document.contains(host), "platform contract does not name \(host)")
        }
        XCTAssertTrue(document.contains("✅ means"), "platform contract does not define completion")
    }

    private func declaredNames(of vocabulary: String, in source: String) -> Set<String> {
        let marker = "= \(vocabulary)(\""

        return Set(source.split(separator: "\n").compactMap { line in
            let code = line.trimmingCharacters(in: .whitespaces)
            guard code.hasPrefix("static let "),
                  let start = code.range(of: marker)?.upperBound,
                  let end = code[start...].firstIndex(of: "\"")
            else { return nil }
            return String(code[start..<end])
        })
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
