// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ContextMenuContract` on a host: a view offers its menu - items, separators and submenus as the tree says them -
/// the menu follows the states its entries read, and one with no entries is none.
@_spi(Host) public enum ContextMenuTests: ConformanceFamily {
    public static let name = "ContextMenu"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aViewOffersItsMenuAsTheTreeSaysIt", covers: [
                Covered(ContextMenuContract.self), Covered(MenuContract.text), Covered(MenuSeparatorContract.self),
                Covered(MenuItemElementContract.text, on: "MenuItem"), Covered(MenuItemElementContract.isEnabled, on: "MenuItem"),
            ]) { s in
                s.start { MenuPage(heard: Received()) }

                s.expect(try s.menu(of: s.element("row")), "Copy;-;!Paste;Share[Mail]")
            },
            ConformanceCase("theMenuFollowsTheStatesItsEntriesRead", covers: [
                Covered(ContextMenuContract.self), Covered(MenuItemElementContract.isEnabled, on: "MenuItem"),
                Covered(ButtonContract.clicked),
            ]) { s in
                s.start { MenuPage(heard: Received()) }
                let row = try s.element("row")

                try s.perform(.activate, on: s.element("allow"))
                try s.settle { try s.menu(of: row) == "Copy;-;Paste;Share[Mail]" }
                s.expect(try s.menu(of: row), "Copy;-;Paste;Share[Mail]", "an item that can now be chosen")

                try s.perform(.activate, on: s.element("more"))
                try s.settle { try s.menu(of: row) == "Copy;-;Paste;Share[Mail;Chat]" }
                s.expect(try s.menu(of: row), "Copy;-;Paste;Share[Mail;Chat]", "an entry added to the submenu")
            },
            ConformanceCase("aMenuWithNoEntriesIsNone", covers: [
                Covered(ContextMenuContract.self), Covered(ButtonContract.clicked),
            ]) { s in
                let entries = State(wrappedValue: ["Open"])
                s.start {
                    VStack {
                        Label("Row").contextMenu {
                            ForEach(entries.wrappedValue, id: \.self) { entry in MenuItem(entry) }
                        }.id("row")
                        Button("Empty").onClicked { entries.wrappedValue = [] }.id("empty")
                    }
                }
                let row = try s.element("row")
                s.expect(try s.menu(of: row), "Open")

                try s.perform(.activate, on: s.element("empty"))
                try s.settle { try s.menu(of: row) == "" }
                s.expect(try s.menu(of: row), "", "no menu offered")
            },
        ]
    }
}

/// A row with a context menu whose entries follow the page's states, saying what the user chose.
struct MenuPage: ContentView {
    let heard: Received<String>

    @State private var canPaste = false
    @State private var shares = ["Mail"]

    var content: any View {
        let (heard, canPaste, shares) = (self.heard, $canPaste, $shares)
        return VStack {
            Label("Row").contextMenu {
                MenuItem("Copy").onClicked { heard.values.append("copy") }.id("copy")
                MenuSeparator().id("separator")
                MenuItem("Paste").isEnabled(canPaste.wrappedValue).onClicked { heard.values.append("paste") }.id("paste")
                Menu("Share") {
                    ForEach(shares.wrappedValue, id: \.self) { share in
                        MenuItem(share).onClicked { heard.values.append("share \(share)") }.id("share \(share)")
                    }
                }.id("share")
            }.id("row")
            Button("Allow paste").onClicked { canPaste.wrappedValue = true }.id("allow")
            Button("More shares").onClicked { shares.wrappedValue.append("Chat") }.id("more")
        }
    }
}
