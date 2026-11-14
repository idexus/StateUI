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
}
