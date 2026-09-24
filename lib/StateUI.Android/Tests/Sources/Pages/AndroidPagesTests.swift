// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidPagesTests: XCTestCase {
    static var allTests: [(String, (AndroidPagesTests) -> () throws -> Void)] {
        [
            ("testAStackShowsItsTopPageUnderItsBarAndGoesBack", testAStackShowsItsTopPageUnderItsBarAndGoesBack),
            ("testAPushAndAPopAreHeardByThePagesInOrder", testAPushAndAPopAreHeardByThePagesInOrder),
            ("testTheBarOpensTheSidebarAndBackClosesIt", testTheBarOpensTheSidebarAndBackClosesIt),
            ("testATabChosenShowsItsPageAndSaysSo", testATabChosenShowsItsPageAndSaysSo),
            ("testAPagesToolbarItemsAreTheBarsActions", testAPagesToolbarItemsAreTheBarsActions),
            ("testAPagesTitleViewStandsInTheBarInPlaceOfItsTitle", testAPagesTitleViewStandsInTheBarInPlaceOfItsTitle),
            ("testAModalStackPresentsOverThePageAndBackTakesItDown", testAModalStackPresentsOverThePageAndBackTakesItDown),
            ("testThePageUnderPagesTheProgramTakesDownShowsAgain", testThePageUnderPagesTheProgramTakesDownShowsAgain),
            ("testAnArrangementTheWindowShowsInsteadAppears", testAnArrangementTheWindowShowsInsteadAppears),
        ]
    }

    /// The root under a bar with its title and no way back; a pushed page with the way back; back pops it.
    func testAStackShowsItsTopPageUnderItsBarAndGoesBack() throws {
        try onMainActor {
            let path = State(wrappedValue: [Int]())
            let host = AndroidRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Root")
                } destination: { number in
                    TitledPage(title: "Detail \(number)")
                }
            }
            host.layOut()
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.title, "Root")
            XCTAssertEqual(navigation.bar.content.navigation, .none)
            XCTAssertFalse(host.goBack(), "no way back from the root")

            path.wrappedValue.append(7)
            host.pump()
            XCTAssertEqual(navigation.bar.content.title, "Detail 7")
            XCTAssertEqual(navigation.bar.content.navigation, .back)
            XCTAssertEqual(navigation.heldViews().count, 2, "the bar and the top page")

            XCTAssertTrue(host.goBack())
            XCTAssertEqual(path.wrappedValue, [])
            XCTAssertEqual(navigation.bar.content.title, "Root")
        }
    }

    /// A push: the root navigates from and disappears, then the pushed page appears and is navigated to; a pop the
    /// other way - every phase rendered before the next is heard.
    func testAPushAndAPopAreHeardByThePagesInOrder() {
        onMainActor {
            let path = State(wrappedValue: [Int]())
            let log = Received<String>()
            let host = AndroidRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Root", log: log)
                } destination: { number in
                    TitledPage(title: "Pushed", log: log)
                }
            }
            XCTAssertEqual(log.values, ["Root appearing", "Root navigatedTo"])

            log.values = []
            path.wrappedValue.append(1)
            host.pump()
            XCTAssertEqual(log.values, [
                "Root navigatingFrom", "Root disappearing", "Root navigatedFrom",
                "Pushed appearing", "Pushed navigatedTo",
            ])

            // The popped page has left the tree, and a page that left hears nothing more.
            log.values = []
            XCTAssertTrue(host.goBack())
            XCTAssertEqual(log.values, ["Root appearing", "Root navigatedTo"])
        }
    }

    /// On a phone the sidebar slides over the detail: the detail's bar shows the sidebar's picture, pressing it
    /// opens the sidebar and says so, and back closes it.
    func testTheBarOpensTheSidebarAndBackClosesIt() throws {
        try onMainActor {
            let open = State(wrappedValue: false)
            let host = AndroidRenderer.running {
                SplitView(open.projectedValue) {
                    TitledPage(title: "Menu", icon: "test_dot.png")
                } detail: {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        TitledPage(title: "Home")
                    } destination: { _ in
                        TitledPage(title: "Deeper")
                    }
                }
            }
            host.layOut()
            let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertTrue(split.overlays)
            XCTAssertEqual(navigation.bar.content.navigation, .sidebar("test_dot.png"))

            navigation.bar.clicked()
            XCTAssertTrue(open.wrappedValue)
            XCTAssertTrue(split.isPresented)

            XCTAssertTrue(host.goBack())
            XCTAssertFalse(open.wrappedValue)
            XCTAssertFalse(split.isPresented)
        }
    }

    /// The tabs' titles along the bottom; a tab the user chooses shows its page and lands on the selection.
    func testATabChosenShowsItsPageAndSaysSo() throws {
        try onMainActor {
            let tab = State(wrappedValue: 0)
            let host = AndroidRenderer.running {
                TabbedView([0, 1]) { number in
                    TitledPage(title: "Tab \(number)")
                }
                .selection(tab.projectedValue)
            }
            host.layOut()
            let tabs = try XCTUnwrap(host.views(AndroidTabbedView.self).first)
            let pages = host.views(AndroidSingleChildView.self)
            XCTAssertTrue(tabs.heldViews().first === pages[0])

            tabs.selectByUser(1)
            XCTAssertEqual(tab.wrappedValue, 1)
            XCTAssertTrue(tabs.heldViews().first === pages[1])
        }
    }

    /// What a page puts on the bar: its actions in their priority's order, the overflow's last, each with its
    /// picture and whether it can be chosen - the picture of one that cannot be dimmed - a destructive one in
    /// the theme's error colour; choosing one runs its handler, and one that cannot be chosen runs nothing.
    func testAPagesToolbarItemsAreTheBarsActions() throws {
        try onMainActor {
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Notes", actions: [
                        ToolbarItem("Delete").placement(.overflow).isDestructive(true)
                            .onClicked { heard.values.append("delete") },
                        ToolbarItem("Save").priority(1).icon("test_wide.png").onClicked { heard.values.append("save") },
                        ToolbarItem("Add").priority(0).icon("test_wide.png").isEnabled(false)
                            .onClicked { heard.values.append("add") },
                    ])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
            }
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.actions.map(\.onBar), [true, true, false])

            let menu = JavaObject(try XCTUnwrap(Java.callObject(navigation.bar.reference, TestMenus.getMenu)))
            XCTAssertEqual(TestMenus.describe(menu), "Add (off) (dimmed picture), Save (picture), Delete (red)")
            for words in ["Add", "Save", "Delete"] { TestMenus.choose(menu, words) }
            host.pump()
            XCTAssertEqual(heard.values, ["save", "delete"])
        }
    }
}

extension AndroidPagesTests {
    /// A page's title view stands in the bar in place of its title; a page pushed over it, with none, shows
    /// its own title and the view leaves the bar; back, and it stands there again.
    func testAPagesTitleViewStandsInTheBarInPlaceOfItsTitle() throws {
        try onMainActor {
            let path = State(wrappedValue: [Int]())
            let host = AndroidRenderer.running {
                NavigationStack(path.projectedValue) {
                    SearchingPage()
                } destination: { _ in
                    TitledPage(title: "Result")
                }
            }
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            let field = try XCTUnwrap(host.views(AndroidTextFieldView.self).first)
            let bar = navigation.bar
            XCTAssertTrue(bar.titleView === field)
            XCTAssertGreaterThanOrEqual(Java.callInt(bar.reference, TestJava.indexOfChild, .object(field.reference)), 0)
            XCTAssertEqual(Self.title(of: bar), "")

            path.wrappedValue = [1]
            host.pump()
            XCTAssertNil(bar.titleView)
            XCTAssertEqual(Java.callInt(bar.reference, TestJava.indexOfChild, .object(field.reference)), -1)
            XCTAssertEqual(Self.title(of: bar), "Result")

            XCTAssertTrue(host.goBack())
            host.pump()
            XCTAssertTrue(bar.titleView === field)
            XCTAssertEqual(Self.title(of: bar), "")
        }
    }

    /// The words the bar shows as its title; none where a view stands in for it.
    @MainActor
    private static func title(of bar: AndroidBarView) -> String {
        Java.frame {
            Java.callObject(bar.reference, TestJava.getToolbarTitle).map { words in
                Java.text(Java.callObject(words, TestJava.toText))
            } ?? ""
        }
    }

    /// A page the modal stack presents stands over the window's page; back takes it down, the stack hears it,
    /// and the page under it shows again.
    func testAModalStackPresentsOverThePageAndBackTakesItDown() {
        onMainActor {
            let sheets = State(wrappedValue: [Int]())
            let log = Received<String>()
            let host = AndroidRenderer.running(reducesMotion: true) { SheetsPage(sheets: sheets, log: log) }
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 1)

            log.values = []
            sheets.wrappedValue = [1]
            host.pump()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 2, "the page, and the sheet over it")
            XCTAssertEqual(
                log.values.filter { $0.hasSuffix("appearing") }, ["Page disappearing", "Sheet 1 appearing"])

            log.values = []
            XCTAssertTrue(host.goBack())
            XCTAssertEqual(sheets.wrappedValue, [])
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 1)
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Page appearing"])
        }
    }

    /// The program shortening the stack takes its pages down after the tree has let them go - a page that left
    /// hears nothing more - and the page under them shows again.
    func testThePageUnderPagesTheProgramTakesDownShowsAgain() {
        onMainActor {
            let sheets = State(wrappedValue: [Int]())
            let log = Received<String>()
            let host = AndroidRenderer.running(reducesMotion: true) { SheetsPage(sheets: sheets, log: log) }
            sheets.wrappedValue = [1, 2]
            host.pump()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 3)

            log.values = []
            sheets.wrappedValue = [1]
            host.pump()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 2)
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Sheet 1 appearing"])

            log.values = []
            sheets.wrappedValue = []
            host.pump()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 1)
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Page appearing"])
        }
    }

    /// A window showing another arrangement: the new one appears, and the one the tree let go hears nothing more.
    func testAnArrangementTheWindowShowsInsteadAppears() {
        onMainActor {
            let stacked = State(wrappedValue: false)
            let path = State(wrappedValue: [Int]())
            let log = Received<String>()
            let host = AndroidRenderer.running {
                if !stacked.wrappedValue { return TitledPage(title: "Page", log: log) }
                return NavigationStack(path.projectedValue) {
                    TitledPage(title: "Root", log: log)
                } destination: { _ in
                    TitledPage(title: "Pushed")
                }
            }

            log.values = []
            stacked.wrappedValue = true
            host.pump()
            XCTAssertEqual(host.views(AndroidLabelView.self).map(\.text), ["Root"])
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Root appearing"])
        }
    }
}

/// A page whose search field stands in its bar in place of its title.
private struct SearchingPage: ContentView {
    @Environment private var page: PageSession
    @State private var query = ""

    var content: any View {
        let page = self.page
        let query = $query
        return Label("Results").onCreated {
            page.title = "Search"
            page.titleView = SearchField(query).placeholder("Search")
        }
    }
}

/// A page that presents its sheets over itself through its window's modal stack.
private struct SheetsPage: ContentView {
    let sheets: State<[Int]>
    let log: Received<String>

    @Environment private var window: WindowSession

    var content: any View {
        let sheets = self.sheets
        let log = self.log
        let window = self.window
        return TitledPage(title: "Page", log: log).onCreated {
            window.modalStack = ModalStack(sheets.projectedValue) { number in
                TitledPage(title: "Sheet \(number)", log: log)
            }
        }
    }
}

/// A page that names itself, and writes each phase it hears into `log`.
private struct TitledPage: ContentView {
    let title: String
    var icon: ImageSource? = nil
    var log: Received<String>? = nil
    var actions: [ToolbarItem] = []

    @Environment private var page: PageSession

    var content: any View {
        let log = self.log
        let title = self.title
        let page = self.page

        return Label(title)
            .onCreated {
                page.title = title
                page.icon = icon
                page.toolbarItems = actions
            }
            .onChanged(page.phase) { log?.values.append("\(title) \(page.phase)") }
    }
}
