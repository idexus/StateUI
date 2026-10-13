// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// A button's menu: a slot after the button's own children, one a button, and how its menu opens - by its click, an
/// arrow, or held - which its menu, its click and the kind it asks make it; another opening made again.
@MainActor
final class ButtonMenuTests: XCTestCase {
    func testAButtonsMenuTravelsAsASlotHoldingItsEntries() {
        let node = Button("Share").menu {
            MenuItem("Mail")
            MenuSeparator()
            Menu("More") { MenuItem("Link") }
        }.node

        XCTAssertEqual(node.children.map(\.type), [.buttonMenu])
        XCTAssertEqual(node.children.first?.children.map(\.type), [.menuItem, .menuSeparator, .menu])
    }

    func testAMenuWrittenAgainStandsInForTheLast() {
        let node = Button("Share")
            .menu { MenuItem("Mail") }
            .menu { MenuItem("Link"); MenuItem("Copy") }
            .node

        XCTAssertEqual(node.children.map(\.type), [.buttonMenu])
        XCTAssertEqual(node.children.first?.children.count, 2)
    }

    func testAButtonOpensItsMenuAsItsMenuItsClickAndItsKindSay() {
        XCTAssertEqual(Button("Go").node.buttonMenuOpening, .none)
        XCTAssertEqual(Button("Go").onClicked {}.node.buttonMenuOpening, .none)
        XCTAssertEqual(Button("Share").menu { MenuItem("Mail") }.node.buttonMenuOpening, .click)
        XCTAssertEqual(Button("Save").onClicked {}.menu { MenuItem("Save as") }.node.buttonMenuOpening, .arrow)
        XCTAssertEqual(Button("Share").menu(.split) { MenuItem("Mail") }.node.buttonMenuOpening, .arrow)
        XCTAssertEqual(Button("Save").onClicked {}.menu(.held) { MenuItem("Save as") }.node.buttonMenuOpening, .hold)
        XCTAssertNil(Button("Share").menu { MenuItem("Mail") }.node.props[.menuKind], "the kind written only as asked")
    }

    /// A button made one kind and described another is made again - the toolkit makes each of its own control - and
    /// one of the same kind is changed in place.
    func testAButtonOfAnotherKindIsMadeAgain() {
        let renders = Renders()
        renders.render(Button("Save").menu { MenuItem("Save as") }.id("b").node)

        let same = renders.render(Button("Save").menu { MenuItem("Save a copy") }.id("b").node)
        XCTAssertFalse(same.replace, "the same kind, another entry")

        let split = renders.render(Button("Save").onClicked {}.menu { MenuItem("Save a copy") }.id("b").node)
        XCTAssertTrue(split.replace, "a click of its own makes a split button")

        let held = renders.render(Button("Save").onClicked {}.menu(.held) { MenuItem("Save a copy") }.id("b").node)
        XCTAssertTrue(held.replace, "held, a button whose menu opens as it is held")

        let plain = renders.render(Button("Save").onClicked {}.id("b").node)
        XCTAssertTrue(plain.replace, "no menu, a button")
    }

    /// A button whose arrow is described otherwise is made again: a toolkit makes a button opening its menu with an
    /// arrow and one without of controls of their own.
    func testAButtonShowingItsArrowOtherwiseIsMadeAgain() {
        let renders = Renders()
        renders.render(Button("Share").menu { MenuItem("Mail") }.id("b").node)

        let bare = renders.render(Button("Share").menu { MenuItem("Mail") }.showsMenuArrow(false).id("b").node)
        XCTAssertTrue(bare.replace, "its arrow taken away")
    }
}
