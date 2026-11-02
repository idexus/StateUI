// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// Every handbook page is named by one rule, so a link to it is written without looking it up.
@MainActor
final class DocumentNamesTests: XCTestCase {
    /// Every Markdown document under `docs/` is named in lowercase words joined by `-` - `motion-and-journeys.md` -
    /// and a folder's own page `README.md`. A page of the control dictionary, under `docs/controls/`, is named as
    /// its contract's type is, with no `-`: `BottomBar.md`, `tiers/TextualElement.md`.
    func testEveryDocumentIsNamedInLowercaseWordsJoinedByHyphens() throws {
        let docs = SourceTree.repository.appendingPathComponent("docs")
        let documents = try SourceTree.files(under: docs, entering: SourceTree.entersSources)
            .filter { $0.hasSuffix(".md") }
        XCTAssertGreaterThan(documents.count, 100, "the walk read almost nothing")
        XCTAssertTrue(documents.contains { $0.hasPrefix("controls/") }, "the walk read no page of the dictionary")

        let misnamed = documents.filter { path in
            let name = SourceTree.name(of: path)
            if name == "README.md" { return false }
            if path.hasPrefix("controls/") { return name.wholeMatch(of: /[A-Z][A-Za-z0-9]*\.md/) == nil }
            return name.wholeMatch(of: /[a-z0-9]+(-[a-z0-9]+)*\.md/) == nil
        }
        XCTAssertEqual(misnamed.map { "docs/\($0)" }, [], "name a page in lowercase words joined by -, a dictionary "
            + "page as its contract's type")
    }
}
