// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host reads a button's menu: the kind of control the button is, from the patch it is made from and as
/// it stands, and its menu's entries.
@MainActor
final class ButtonMenuTests: XCTestCase {
    private func button(menu: Bool, clicks: Bool) -> HostPatch {
        var button = HostPatch(id: .manual("button"), type: .button)
        if clicks { button.events = .replace([.clicked: 1]) }
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

    func testAButtonIsMadeTheKindItsMenuAndItsClickSay() {
        XCTAssertEqual(ButtonMenu.kind(made: button(menu: false, clicks: true)), .plain)
        XCTAssertEqual(ButtonMenu.kind(made: button(menu: true, clicks: false)), .menu)
        XCTAssertEqual(ButtonMenu.kind(made: button(menu: true, clicks: true)), .split)
        XCTAssertEqual(ButtonMenu.kind(made: nil), .plain)
    }

    func testAMountedButtonSaysItsKindAndItsEntries() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(button(menu: true, clicks: false), complete: true)
        let mounted = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(ButtonMenu.kind(of: mounted), .menu)
        XCTAssertEqual(ButtonMenu.entries(of: mounted).map(\.kind), [.item, .separator, .item])
        XCTAssertTrue(mounted.children.first?.isViewless == true, "a button's menu has no view of its own")
    }
}
