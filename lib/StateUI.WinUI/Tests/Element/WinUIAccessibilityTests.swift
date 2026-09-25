// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

/// A button whose words for assistive technology a click takes away.
private struct NamedPage: ContentView {
    @State private var named = true

    var content: any View {
        VStack {
            if named {
                Button("OK").accessibilityLabel("Confirm").accessibilityHint("Saves the form")
                    .accessibilityIdentifier("confirm")
            } else {
                Button("OK")
            }
            Button("Forget").onClicked { named = false }
        }
    }
}

final class WinUIAccessibilityTests: XCTestCase {
    /// What an element says of itself reaches assistive technology: its name, its help and its identifier; taken
    /// away, the control's own name stands again.
    func testAnElementsWordsReachAssistiveTechnology() throws {
        try onUIThread {
            let host = WinUIRenderer.running { NamedPage() }
            let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            let words = button.automationWords
            XCTAssertEqual(words.name, "Confirm")
            XCTAssertEqual(words.help, "Saves the form")
            XCTAssertEqual(words.identifier, "confirm")

            try XCTUnwrap(host.views(WinUIButtonView.self).last).invoke()
            let plain = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            host.settle { plain.automationWords.name == "OK" }
            XCTAssertEqual(plain.automationWords.name, "OK", "the control's own name")
            XCTAssertEqual(plain.automationWords.help, "")
        }
    }

    /// A heading says its level.
    func testAHeadingSaysItsLevel() throws {
        try onUIThread {
            let host = WinUIRenderer.running { VStack { Label("Chapter").accessibilityHeadingLevel(.level2) } }

            XCTAssertEqual(try XCTUnwrap(host.views(WinUILabelView.self).first).automationFacts.heading, 2)
        }
    }

    /// An element hidden is skipped, and one left out with its children takes them with it; an element that says
    /// nothing is met as it is.
    func testAHiddenElementIsSkippedAndOneLeftOutTakesItsChildren() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Label("skipped").isAccessibilityHidden(true)
                    Label("read")
                    VStack {
                        Button("inside")
                        Label("inside too")
                    }
                    .automationExcludedWithChildren(true)
                }
            }
            let labels = host.views(WinUILabelView.self)
            XCTAssertFalse(labels[0].automationFacts.isControl, "a hidden label is skipped")
            XCTAssertTrue(labels[1].automationFacts.isContent, "a label that says nothing is read")

            let excluded = try XCTUnwrap(host.views(WinUIStackView.self).last)
            XCTAssertFalse(excluded.automationFacts.isControl)
            XCTAssertEqual(excluded.automationFacts.children, 0, "nothing in it is met")
        }
    }
}
