// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host reads a button's menu: how it opens, from the patch it is made from and as it stands, whether its
/// arrow shows, and its menu's entries.
@MainActor
final class ButtonMenuTests: XCTestCase {
    private func button(menu: Bool, clicks: Bool, kind: ButtonMenuKind? = nil, arrow: Bool? = nil) -> HostPatch {
        var button = HostPatch(id: .manual("button"), type: .button)
        if clicks { button.events = .replace([.clicked: 1]) }
        if let kind { button.properties[.menuKind] = kind.propValue }
        if let arrow { button.properties[.showsMenuArrow] = .bool(arrow) }
        if menu {
            var slot = HostPatch(id: .manual("menu"), type: .buttonMenu)
            slot.children = .arranged([
                HostPatch(id: .manual("mail"), type: .menuItem),
                HostPatch(id: .manual("line"), type: .menuSeparator),
                HostPatch(id: .manual("link"), type: .menuItem),
            ])
            button.children = .arranged([slot])
        }
        return button
    }

    func testAButtonIsMadeToOpenItsMenuAsItsMenuItsClickAndItsKindSay() {
        XCTAssertEqual(ButtonMenu.opening(made: button(menu: false, clicks: true)), .none)
        XCTAssertEqual(ButtonMenu.opening(made: button(menu: true, clicks: false)), .click)
        XCTAssertEqual(ButtonMenu.opening(made: button(menu: true, clicks: true)), .arrow)
        XCTAssertEqual(ButtonMenu.opening(made: button(menu: true, clicks: true, kind: .held)), .hold)
        XCTAssertEqual(ButtonMenu.opening(made: button(menu: true, clicks: false, kind: .split)), .arrow)
        XCTAssertEqual(ButtonMenu.opening(made: nil), .none)
    }

    /// A button opening its menu by its click shows its arrow unless the tree says it shows none; another shows
    /// none of its own.
    func testAnArrowShowsUnlessTheTreeSaysNone() throws {
        func shows(_ patch: HostPatch) throws -> Bool {
            let runtime = HostRuntime.still()
            runtime.tree.apply(patch, complete: true)
            return ButtonMenu.showsArrow(try XCTUnwrap(runtime.tree.root))
        }
        XCTAssertTrue(try shows(button(menu: true, clicks: false)))
        XCTAssertFalse(try shows(button(menu: true, clicks: false, arrow: false)))
        XCTAssertFalse(try shows(button(menu: true, clicks: true)), "a split button's arrow is its own part")
        XCTAssertFalse(try shows(button(menu: true, clicks: true, kind: .held)))
    }

    func testAButtonIsMadeShowingItsArrowAsItsPatchSays() {
        XCTAssertTrue(ButtonMenu.showsArrow(made: button(menu: true, clicks: false)))
        XCTAssertFalse(ButtonMenu.showsArrow(made: button(menu: true, clicks: false, arrow: false)))
        XCTAssertFalse(ButtonMenu.showsArrow(made: button(menu: true, clicks: true)), "a split button's arrow is a part")
        XCTAssertFalse(ButtonMenu.showsArrow(made: button(menu: true, clicks: true, kind: .held)))
        XCTAssertFalse(ButtonMenu.showsArrow(made: button(menu: false, clicks: false)))
    }

    func testAMountedButtonSaysItsKindAndItsEntries() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(button(menu: true, clicks: false), complete: true)
        let mounted = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(ButtonMenu.opening(of: mounted), .click)
        XCTAssertEqual(ButtonMenu.entries(of: mounted).map(\.kind), [.item, .separator, .item])
        XCTAssertTrue(mounted.children.first?.isViewless == true, "a button's menu has no view of its own")
    }
}
