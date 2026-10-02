// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `MenuBarContract` on a host: the menus the visible page declares stand on its window's bar with their entries,
/// choosing an item runs its handler, the bar shows what the page declares again, follows the visible page, and a
/// menu of an id joins the one declared around it - a section of its own, an entry of an id in the outer one's place.
@_spi(Host) public enum MenuBarTests: ConformanceFamily {
    public static let name = "MenuBar"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("thePagesMenusStandOnItsWindowsBar", proves: [
                Covered(MenuBarContract.self), Covered(MenuContract.text), Covered(MenuItemElementContract.isEnabled, on: "MenuItem"),
            ]) { s in
                s.start { onAStack(MenusPage(heard: Received())) }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.settle { try s.menu(of: window) == "File[New;-;Recent[a.txt]];Edit[!Undo]" }
                s.expect(try s.menu(of: window), "File[New;-;Recent[a.txt]];Edit[!Undo]")
            },
            ConformanceCase("anItemChosenFromTheBarRunsItsHandler", proves: [
                Covered(MenuBarContract.self), Covered(MenuItemElementContract.clicked, on: "MenuItem"),
            ]) { s in
                let heard = Received<String>()
                s.start { onAStack(MenusPage(heard: heard)) }

                try s.perform(.activate, on: s.element("open a.txt"))
                s.settle { heard.values == ["open a.txt"] }
                try s.perform(.activate, on: s.element("new"))
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["open a.txt", "new"])
            },
            ConformanceCase("theBarShowsTheMenusThePageDeclaresAgain", proves: [
                Covered(MenuBarContract.self),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                s.start { onAStack(MenusPage(heard: Received())) }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.perform(.activate, on: s.element("more"))
                try s.settle { try s.menu(of: window) == "File[New;-;Recent[a.txt;b.txt]];Edit[!Undo]" }
                s.expect(try s.menu(of: window), "File[New;-;Recent[a.txt;b.txt]];Edit[!Undo]")
            },
            ConformanceCase("theBarFollowsTheVisiblePage", proves: [Covered(MenuBarContract.self)]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        MenusPage(heard: Received())
                    } destination: { _ in Text("Note") }
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
            ConformanceCase("aMenuJoinsTheOneOfItsIdDeclaredAroundIt", proves: [Covered(MenuBarContract.self)]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        Text("Home")
                    } destination: { _ in
                        Text("Document").menuBar {
                            Menu("File") {
                                MenuItem("Save document").id("save")
                                MenuItem("Export")
                            }
                            .id("file")
                            Menu("Format") { MenuItem("Bold") }
                        }
                    }
                    .menuBar {
                        Menu("File") {
                            MenuItem("New")
                            MenuItem("Save").isEnabled(false).id("save")
                        }
                        .id("file")
                    }
                }
                let window = try s.element(ofType: WindowContract.nodeType)
                try s.settle { try s.menu(of: window) == "File[New;!Save]" }
                s.expect(try s.menu(of: window), "File[New;!Save]", "the stack's on its first page")

                path.wrappedValue = [1]
                try s.settle { try s.menu(of: window) == "File[New;Save document;-;Export];Format[Bold]" }
                s.expect(try s.menu(of: window), "File[New;Save document;-;Export];Format[Bold]",
                         "the page's entry in the outer one's place, its own a section, its own menu after")

                path.wrappedValue = []
                try s.settle { try s.menu(of: window) == "File[New;!Save]" }
                s.expect(try s.menu(of: window), "File[New;!Save]", "the page's gone with it, nothing restored")
            },
            ConformanceCase("aDeclarationsOrderMovesItsMenusAndSections", proves: [
                Covered(MenuBarContract.order),
            ]) { s in
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        Text("Document").menuBar(order: -1) {
                            Menu("File") { MenuItem("Open") }.id("file")
                            Menu("Go") { MenuItem("Back") }
                        }
                    } destination: { _ in Text("Note") }
                    .menuBar { Menu("File") { MenuItem("New") }.id("file") }
                }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.settle { try s.menu(of: window) == "Go[Back];File[Open;-;New]" }
                s.expect(try s.menu(of: window), "Go[Back];File[Open;-;New]", "lower earlier, in the bar and in a menu")
            },
        ]
    }
}

/// `page` as the first page of a stack, whose bar a host with menus on its bar puts them on.
func onAStack(_ page: MenusPage) -> NavigationStack {
    NavigationStack(State(wrappedValue: [Int]()).projectedValue) { page } destination: { _ in Text("Note") }
}

/// A page declaring its menus - File, with a submenu of what a state lists, and Edit - and saying what the user
/// chose.
struct MenusPage: ContentView {
    let heard: Received<String>

    @State private var recent = ["a.txt"]

    var content: some View {
        let (heard, recent) = (heard, $recent)
        return VStack { Button("More").onClicked { recent.wrappedValue.append("b.txt") }.id("more") }
            .menuBar {
                Menu("File") {
                    MenuItem("New").onClicked { heard.values.append("new") }.id("new")
                    MenuSeparator()
                    Menu("Recent") {
                        recent.wrappedValue.map { file in
                            MenuItem(file).onClicked { heard.values.append("open \(file)") }.id("open \(file)")
                        }
                    }
                }
                Menu("Edit") { MenuItem("Undo").isEnabled(false) }
            }
    }
}
