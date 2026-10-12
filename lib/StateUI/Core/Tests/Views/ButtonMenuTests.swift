// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// A button's menu: a slot after the button's own children, one a button, and the kind of control its menu and its
/// click make it - another kind made again.
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

    func testAButtonIsTheKindItsMenuAndItsClickMakeIt() {
        XCTAssertEqual(Button("Go").node.buttonMenuKind, .plain)
        XCTAssertEqual(Button("Go").onClicked {}.node.buttonMenuKind, .plain)
        XCTAssertEqual(Button("Share").menu { MenuItem("Mail") }.node.buttonMenuKind, .menu)
        XCTAssertEqual(Button("Save").onClicked {}.menu { MenuItem("Save as") }.node.buttonMenuKind, .split)
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

        let plain = renders.render(Button("Save").onClicked {}.id("b").node)
        XCTAssertTrue(plain.replace, "no menu, a button")
    }
}
