// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import UIKit
import XCTest

/// A link stands as large as its words, so a touch on them reaches it, and grays while it cannot be chosen.
@MainActor
final class UIKitLinkViewTests: XCTestCase {
    /// A touch on each link's words reaches that link where links stand with other controls in a scrolled page.
    func testATouchOnEachLinksWordsReachesItInAPage() throws {
        let page = State(wrappedValue: "https://www.swift.org")
        let host = UIKitRenderer.running {
            ScrollView {
                VStack {
                    Link("Swift's home page", destination: "https://www.swift.org")
                    Link("Write to us", destination: "mailto:hello@example.com")
                    Link("The page chosen below", destination: page.projectedValue)
                    Picker(["https://www.swift.org", "https://developer.apple.com"], selection: page.projectedValue) { $0 }
                    Text("Opened 0 times")
                }
                .spacing(12)
            }
        }
        defer { host.finish() }
        host.layOut()
        let links = host.views(UIKitLinkView.self)
        XCTAssertEqual(links.count, 3)
        host.settle { links.allSatisfy { $0.bounds.height > 0 } }
        for link in links {
            let window = try XCTUnwrap(link.window)
            let words = try XCTUnwrap(link.titleLabel)
            let middle = words.convert(CGPoint(x: words.bounds.midX, y: words.bounds.midY), to: window)
            let hit = window.hitTest(middle, with: nil)
            XCTAssertTrue(hit === link, "\(link.wordsForTesting): \(link.frame), words at \(middle), hit \(String(describing: hit))")
        }
    }

    /// A link that cannot be chosen shows its words in another color than the link color.
    func testALinkThatCannotBeChosenIsGrayed() throws {
        let enabled = State(wrappedValue: true)
        let host = UIKitRenderer.running {
            VStack { Link("Swift's home page", destination: "https://www.swift.org").isEnabled(enabled.wrappedValue) }
        }
        defer { host.finish() }
        host.layOut()
        let link = try XCTUnwrap(host.views(UIKitLinkView.self).first)
        link.layoutIfNeeded()
        let chosen = try XCTUnwrap(link.titleLabel?.textColor)

        enabled.wrappedValue = false
        host.settle { !link.isEnabled }
        link.layoutIfNeeded()
        XCTAssertNotEqual(link.titleLabel?.textColor, chosen, "grayed while it cannot be chosen")
    }
}
