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

    /// What a page puts on the bar: its actions, the primary ones first; picking one runs its handler.
    func testAPagesToolbarItemsAreTheBarsActions() throws {
        try onMainActor {
            let saved = Received<Int>()
            let host = AndroidRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Notes", actions: [
                        ToolbarItem("Delete").placement(.overflow),
                        ToolbarItem("Save").onClicked { saved.values.append(1) },
                    ])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
            }
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)

            XCTAssertEqual(navigation.bar.content.actions.map(\.title), ["Save", "Delete"])
            XCTAssertEqual(navigation.bar.content.actions.map(\.overflows), [false, true])

            navigation.bar.onAction?(0)
            XCTAssertEqual(saved.values, [1])
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
