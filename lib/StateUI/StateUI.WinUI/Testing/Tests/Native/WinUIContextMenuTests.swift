// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

/// Two stacks offering a menu a button empties, the second hearing taps too.
private struct MenuStacksPage: ContentView {
    @State private var entries = ["Open"]

    var content: some View {
        let entries = $entries
        return VStack {
            HStack { Label("menu") }
                .width(200)
                .height(40)
                .contextMenu { entries.wrappedValue.map { MenuItem($0).id($0) } }
            HStack { Label("tapped") }
                .width(200)
                .height(40)
                .onTapped {}
                .contextMenu { entries.wrappedValue.map { MenuItem($0).id($0) } }
            Button("Empty").onClicked { entries.wrappedValue = [] }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

final class WinUIContextMenuTests: XCTestCase {
    /// A stack offering a menu is hit where it draws nothing, so a right click past its words opens the menu;
    /// once the menu goes, it is hit there only while it still hears taps.
    func testAStackOfferingAMenuIsHitWhereItDrawsNothing() throws {
        try onUIThread {
            let host = WinUIRenderer.running { MenuStacksPage() }
            let stacks = host.views(WinUIStackView.self).filter { $0.menus == "Open" }
            XCTAssertEqual(stacks.count, 2)
            XCTAssertTrue(stacks[0].hits(190, 20))
            XCTAssertTrue(stacks[1].hits(190, 20))

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { stacks[0].menus == "" }
            XCTAssertFalse(stacks[0].hits(190, 20), "no menu, nothing heard: hit only on its words")
            XCTAssertTrue(stacks[1].hits(190, 20), "still hearing taps")
        }
    }
}
