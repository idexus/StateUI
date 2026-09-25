// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

/// A row with a context menu whose entries follow the page's states, saying what the user chose.
private struct MenuPage: ContentView {
    let heard: Received<String>
    @State private var canPaste = false
    @State private var shares = ["Mail"]

    var content: any View {
        let heard = heard
        let canPaste = $canPaste
        let shares = $shares
        return VStack {
            Label("Row")
                .contextMenu {
                    MenuItem("Copy").onClicked { heard.values.append("copy") }
                    MenuSeparator()
                    MenuItem("Paste").isEnabled(canPaste.wrappedValue).onClicked { heard.values.append("paste") }
                    Menu("Share") {
                        ForEach(shares.wrappedValue, id: \.self) { share in
                            MenuItem(share).onClicked { heard.values.append("share \(share)") }
                        }
                    }
                }
            Button("Allow paste").onClicked { canPaste.wrappedValue = true }
            Button("More shares").onClicked { shares.wrappedValue.append("Chat") }
        }
    }
}

/// A row whose context menu holds what a state lists, and so none once the list empties.
private struct EmptyingMenuPage: ContentView {
    @State private var entries = ["Open"]

    var content: any View {
        let entries = $entries
        return VStack {
            Label("Row")
                .contextMenu {
                    ForEach(entries.wrappedValue, id: \.self) { entry in MenuItem(entry) }
                }
            Button("Empty").onClicked { entries.wrappedValue = [] }
        }
    }
}

/// Two stacks offering a menu a button empties, the second hearing taps too.
private struct MenuStacksPage: ContentView {
    @State private var entries = ["Open"]

    var content: any View {
        let entries = $entries
        return VStack {
            HStack { Label("menu") }
                .width(200)
                .height(40)
                .contextMenu { ForEach(entries.wrappedValue, id: \.self) { entry in MenuItem(entry) } }
            HStack { Label("tapped") }
                .width(200)
                .height(40)
                .onTapped {}
                .contextMenu { ForEach(entries.wrappedValue, id: \.self) { entry in MenuItem(entry) } }
            Button("Empty").onClicked { entries.wrappedValue = [] }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

final class WinUIContextMenuTests: XCTestCase {
    /// A view's context menu holds its items, separators and submenus as the tree says them, and choosing an
    /// item runs that item's handler.
    func testAViewsContextMenuHoldsItsEntriesAndRunsTheChosenOne() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running { MenuPage(heard: heard) }
            let row = try XCTUnwrap(host.views(WinUILabelView.self).first)
            XCTAssertEqual(row.contextMenu, "Copy;-;!Paste;Share[Mail]")

            stateui_winui_context_menu_choose(row.handle, 2)
            host.settle { heard.values == ["share Mail"] }
            stateui_winui_context_menu_choose(row.handle, 0)
            host.settle { heard.values.count == 2 }
            XCTAssertEqual(heard.values, ["share Mail", "copy"])
        }
    }

    /// The menu follows the states its entries read: an item that becomes choosable, an entry added to a submenu.
    func testTheMenuFollowsTheStatesItsEntriesRead() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running { MenuPage(heard: heard) }
            let row = try XCTUnwrap(host.views(WinUILabelView.self).first)
            let buttons = host.views(WinUIButtonView.self)

            buttons[0].invoke()
            host.settle { row.contextMenu == "Copy;-;Paste;Share[Mail]" }
            XCTAssertEqual(row.contextMenu, "Copy;-;Paste;Share[Mail]")
            buttons[1].invoke()
            host.settle { row.contextMenu == "Copy;-;Paste;Share[Mail;Chat]" }
            XCTAssertEqual(row.contextMenu, "Copy;-;Paste;Share[Mail;Chat]")

            stateui_winui_context_menu_choose(row.handle, 3)
            host.settle { heard.values == ["share Chat"] }
            XCTAssertEqual(heard.values, ["share Chat"])
        }
    }

    /// A context menu with no entries is none: the view offers no menu.
    func testAMenuWithNoEntriesIsTakenAway() throws {
        try onUIThread {
            let host = WinUIRenderer.running { EmptyingMenuPage() }
            let row = try XCTUnwrap(host.views(WinUILabelView.self).first)
            XCTAssertEqual(row.contextMenu, "Open")

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { row.contextMenu == "" }
            XCTAssertEqual(row.contextMenu, "")
        }
    }

    /// A stack offering a menu is hit where it draws nothing, so a right click past its words opens the menu;
    /// once the menu goes, it is hit there only while it still hears taps.
    func testAStackOfferingAMenuIsHitWhereItDrawsNothing() throws {
        try onUIThread {
            let host = WinUIRenderer.running { MenuStacksPage() }
            let stacks = host.views(WinUIStackView.self).filter { $0.contextMenu == "Open" }
            XCTAssertEqual(stacks.count, 2)
            XCTAssertTrue(stacks[0].hits(190, 20))
            XCTAssertTrue(stacks[1].hits(190, 20))

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { stacks[0].contextMenu == "" }
            XCTAssertFalse(stacks[0].hits(190, 20), "no menu, nothing heard: hit only on its words")
            XCTAssertTrue(stacks[1].hits(190, 20), "still hearing taps")
        }
    }
}

extension WinUIView {
    /// The view's context menu as the relay reads it: items by caption, "!" before one that cannot be chosen, "-"
    /// a separator, a submenu's entries in brackets; empty for none.
    var contextMenu: String {
        let length = Int(stateui_winui_context_menu(handle, nil, 0))
        var bytes = [CChar](repeating: 0, count: length + 1)
        _ = stateui_winui_context_menu(handle, &bytes, Int32(bytes.count))
        return String(decoding: bytes.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
