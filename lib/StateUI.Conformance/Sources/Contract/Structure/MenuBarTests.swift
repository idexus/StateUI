// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `MenuBarContract` on a host: the menus the visible page writes stand on its window's bar with their entries,
/// choosing an item runs its handler, the bar shows what the page writes again, and follows the visible page.
@_spi(Host) public enum MenuBarTests: ConformanceFamily {
    public static let name = "MenuBar"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("thePagesMenusStandOnItsWindowsBar", covers: [
                Covered(MenuBarContract.self), Covered(MenuContract.text), Covered(MenuItemElementContract.isEnabled, on: "MenuItem"),
            ]) { s in
                s.start { MenusPage(heard: Received()) }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.settle { try s.menu(of: window) == "File[New;-;Recent[a.txt]];Edit[!Undo]" }
                s.expect(try s.menu(of: window), "File[New;-;Recent[a.txt]];Edit[!Undo]")
            },
            ConformanceCase("anItemChosenFromTheBarRunsItsHandler", covers: [
                Covered(MenuBarContract.self), Covered(MenuItemElementContract.clicked, on: "MenuItem"),
            ]) { s in
                let heard = Received<String>()
                s.start { MenusPage(heard: heard) }

                try s.perform(.activate, on: s.element("open a.txt"))
                s.settle { heard.values == ["open a.txt"] }
                try s.perform(.activate, on: s.element("new"))
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["open a.txt", "new"])
            },
            ConformanceCase("theBarShowsTheMenusThePageWritesAgain", covers: [
                Covered(MenuBarContract.self), Covered(ButtonContract.clicked),
            ]) { s in
                s.start { MenusPage(heard: Received()) }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.perform(.activate, on: s.element("more"))
                try s.settle { try s.menu(of: window) == "File[New;-;Recent[a.txt;b.txt]];Edit[!Undo]" }
                s.expect(try s.menu(of: window), "File[New;-;Recent[a.txt;b.txt]];Edit[!Undo]")
            },
            ConformanceCase("theBarFollowsTheVisiblePage", covers: [Covered(MenuBarContract.self)]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        MenusPage(heard: Received())
                    } destination: { _ in Label("Note") }
                }
                let window = try s.element(ofType: WindowContract.nodeType)
                try s.settle { try s.menu(of: window) != "" }

                path.wrappedValue = [1]
                try s.settle { try s.menu(of: window) == "" }
                s.expect(try s.menu(of: window), "", "a page with no menus leaves none")

                path.wrappedValue = []
                try s.settle { try s.menu(of: window) != "" }
                s.expect(try s.menu(of: window), "File[New;-;Recent[a.txt]];Edit[!Undo]", "back, its menus stand again")
            },
        ]
    }
}

/// A page writing its menus into its session - File, with a submenu of what a state lists, and Edit - and saying
/// what the user chose.
struct MenusPage: ContentView {
    let heard: Received<String>

    @State private var recent = ["a.txt"]
    @Environment private var page: PageSession

    private var menus: [Menu] {
        let heard = heard
        return [
            Menu("File") {
                MenuItem("New").onClicked { heard.values.append("new") }.id("new")
                MenuSeparator()
                Menu("Recent") {
                    ForEach(recent, id: \.self) { file in
                        MenuItem(file).onClicked { heard.values.append("open \(file)") }.id("open \(file)")
                    }
                }
            },
            Menu("Edit") { MenuItem("Undo").isEnabled(false) },
        ]
    }

    var content: any View {
        let (page, recent, menus) = (self.page, $recent, self.menus)
        return VStack { Button("More").onClicked { recent.wrappedValue.append("b.txt") }.id("more") }
            .onCreated { page.menuBar = menus }
            .onChanged(recent.wrappedValue) { page.menuBar = menus }
    }
}
