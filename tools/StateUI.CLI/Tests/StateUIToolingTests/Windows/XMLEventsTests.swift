// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class XMLEventsTests: XCTestCase {
    /// Elements, attributes in either quote, an element closing itself, text with its references and character data
    /// are the events in order; the byte order mark, the declaration and comments are none.
    func testADocumentIsItsElementsInOrder() throws {
        let document = Data("""
            \u{FEFF}<?xml version="1.0" encoding="utf-8"?>
            <!-- before -->
            <Fragment xmlns="urn:a">
              <Path>A &amp; B &#x41;&#66; &lt;é&gt;</Path>
              <Interface Name='I&apos;s' InterfaceId = "1" />
              <![CDATA[<raw> & ]]>
            </Fragment>

            """.utf8)
        let events = try XMLEvents.read(document).filter { if case .text(let text) = $0 { !text.allSatisfy(\.isWhitespace) } else { true } }
        XCTAssertEqual(events, [
            .start(name: "Fragment", attributes: ["xmlns": "urn:a"]),
            .start(name: "Path", attributes: [:]),
            .text("A & B AB <é>"),
            .end(name: "Path"),
            .start(name: "Interface", attributes: ["Name": "I's", "InterfaceId": "1"]),
            .end(name: "Interface"),
            .text("<raw> & "),
            .end(name: "Fragment"),
        ])
    }

    /// A document is refused where it is not well-formed: each reason is said.
    func testADocumentNotWellFormedIsRefused() {
        let refused: [(String, String)] = [
            ("<Fragment><Extensions>", "<Extensions> is never closed"),
            ("<A><B></A></B>", "</A> where <B> is open"),
            ("text<A/>", "text outside the root"),
            ("<A/><B/>", "a second root"),
            ("<A b=c/>", "<A>'s b is not one quoted value"),
            ("<A b='1' b='2'/>", "<A>'s b is not one quoted value"),
            ("<A b/>", "<A> holds a broken attribute"),
            ("<A>&nbsp;</A>", "&nbsp; is no reference"),
            ("<!-- only -->", "no root"),
            ("<A><!-- open", "no --> ends what opened at byte 7"),
        ]
        for (document, reason) in refused {
            XCTAssertThrowsError(try XMLEvents.read(Data(document.utf8)), document) {
                XCTAssertEqual($0 as? XMLEvents.Refusal, XMLEvents.Refusal(reason: reason), document)
            }
        }
    }
}
