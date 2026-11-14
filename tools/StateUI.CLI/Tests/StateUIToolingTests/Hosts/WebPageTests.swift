// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class WebPageTests: XCTestCase {
    private let template = """
        <head>
        {{head}}
        <link href="./stateui-web.css?v={{stamp}}">
        {{scripts}}
        <script>start("./{{module}}?v={{stamp}}")</script>
        <div aria-label="{{application}}">{{application}}</div>
        """

    /// With no head of its own the page is titled and named after the application; its scripts load before it starts,
    /// each address carrying the build's stamp.
    func testAPageWithNoHeadIsNamedAfterTheApplication() {
        let page = WebPage.index(template, head: "", application: "Notes", module: "NotesWeb.wasm", scripts: ["a.js", "b.js"], stamp: 7)
        XCTAssertEqual(page, """
            <head>
            <title>Notes</title>
            <link href="./stateui-web.css?v=7">
            <script type="module" src="./a.js?v=7"></script><script type="module" src="./b.js?v=7"></script>
            <script>start("./NotesWeb.wasm?v=7")</script>
            <div aria-label="Notes">Notes</div>
            """)
    }

    /// The head stands as written, its title naming the page; the page says its application-name, else its title, a
    /// quote written as HTML's - and a mark in the head is the head's own words, never filled.
    func testTheHeadStandsAsWrittenAndNamesThePage() {
        let titled = WebPage.index(template, head: "<title>My Notes</title>\n<meta name=\"x\" content=\"{{stamp}}\">\n",
                                   application: "Notes", module: "m.wasm", scripts: [], stamp: 7)
        XCTAssertTrue(titled.contains("<head>\n<title>My Notes</title>\n<meta name=\"x\" content=\"{{stamp}}\">\n<link"))
        XCTAssertTrue(titled.contains(">My Notes</div>"))
        let named = WebPage.index(template, head: "<meta name=\"application-name\" content=\"Notebook\">\n<title>T</title>",
                                  application: "Notes", module: "m.wasm", scripts: [], stamp: 7)
        XCTAssertTrue(named.contains("aria-label=\"Notebook\""), named)
        let quoted = WebPage.index(template, head: "<title>The \"Notes\"</title>", application: "Notes", module: "m.wasm", scripts: [], stamp: 7)
        XCTAssertTrue(quoted.contains("aria-label=\"The &quot;Notes&quot;\""), quoted)
    }

    /// On the library's own template: the head's head stands as written - the characters a substitution reads as its
    /// own included - its title the page's only one, no mark left; a `Page` script is laid beside the page and loaded
    /// once, and `head.html` is written in, never laid beside.
    func testTheLibrarysPageHoldsTheHeadAsWritten() throws {
        let head = #"""
            <title>Notes - kept & found</title>
            <meta name="description" content="Notes \ kept # and / found &amp; read">
            <link rel="canonical" href="https://example.com/notes/#top">
            """#
        let (page, staging) = try assembled(head: head, scripts: ["notes.js"])
        XCTAssertTrue(page.contains(head), page)
        XCTAssertEqual(page.components(separatedBy: "<title>").count - 1, 1, page)
        XCTAssertFalse(page.contains("{{"), page)
        XCTAssertEqual(page.components(separatedBy: "src=\"./notes.js?v=").count - 1, 1, page)
        XCTAssertTrue(page.contains(#"<div class="stateui-loading-name">Notes - kept & found</div>"#), page)
        XCTAssertTrue(FileManager.default.fileExists(atPath: staging.appendingPathComponent("notes.js").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.appendingPathComponent("head.html").path))

        let (plain, _) = try assembled(head: nil, scripts: [])
        XCTAssertTrue(plain.contains("<title>Notes</title>"), plain)
        XCTAssertTrue(plain.contains(#"aria-label="Notes""#), plain)
        XCTAssertFalse(plain.contains("{{"), plain)
    }

    /// The page of an application named Notes, its module an empty file, laid on this checkout's template.
    private func assembled(head: String?, scripts: [String]) throws -> (page: String, staging: URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("WebPageTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let application = folder.appendingPathComponent("Notes")
        let page = application.appendingPathComponent("Platforms/Web/Page")
        let binaries = folder.appendingPathComponent("products")
        let staging = folder.appendingPathComponent("site")
        for each in [page, binaries, staging] {
            try FileManager.default.createDirectory(at: each, withIntermediateDirectories: true)
        }
        try Data().write(to: binaries.appendingPathComponent("NotesWeb.wasm"))
        if let head {
            try Data(head.utf8).write(to: page.appendingPathComponent("head.html"))
        }
        for script in scripts {
            try Data("// \(script)\n".utf8).write(to: page.appendingPathComponent(script))
        }
        try WebPage(application: application, name: "Notes", product: "NotesWeb", binaries: binaries,
                    library: ProjectReaderTests.repository, stamp: 7).assemble(in: staging)
        return (try String(contentsOf: staging.appendingPathComponent("index.html"), encoding: .utf8), staging)
    }
}
