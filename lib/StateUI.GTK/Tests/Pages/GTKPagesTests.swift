// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import StateUIConformance
import XCTest

final class GTKPagesTests: XCTestCase {
    /// Each page of a stack stands in a frame with its own header bar, named as the page says; the top page names
    /// the window; the user's back takes the top page off the path.
    func testAStacksPagesCarryTheirHeaderBarsAndTheWayBack() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = GTKRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Root")
                } destination: { number in
                    TitledPage(title: "Detail \(number)")
                }
            }
            let navigation = try XCTUnwrap(host.views(GTKNavigationView.self).first)
            XCTAssertEqual(navigation.frames.map(\.chrome.title), ["Root"])
            XCTAssertEqual(host.windowTitle, "Root")
            XCTAssertFalse(host.goBack(), "no way back from the root")

            path.wrappedValue.append(7)
            host.runtime.pump.turn()
            XCTAssertEqual(navigation.frames.map(\.chrome.title), ["Root", "Detail 7"])
            XCTAssertEqual(navigation.visiblePageTitle, "Detail 7", "GTK shows the pushed page")
            XCTAssertEqual(host.windowTitle, "Detail 7")

            XCTAssertTrue(host.goBack())
            XCTAssertEqual(path.wrappedValue, [], "the user's back pops the page")
            XCTAssertEqual(navigation.frames.map(\.chrome.title), ["Root"])
            XCTAssertEqual(host.windowTitle, "Root")
        }
    }

    /// A push: the root navigates from and disappears, then the pushed page appears and is navigated to; a pop the
    /// other way - every phase rendered before the next is heard.
    func testAPushAndAPopAreHeardByThePagesInOrder() {
        onUIThread {
            let path = State(wrappedValue: [Int]())
            let log = Received<String>()
            let host = GTKRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Root", log: log)
                } destination: { _ in
                    TitledPage(title: "Pushed", log: log)
                }
            }
            XCTAssertEqual(log.values, ["Root appearing", "Root navigatedTo"])

            log.values = []
            path.wrappedValue.append(1)
            host.runtime.pump.turn()
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

    /// A page shown by itself stands in the window's own frame, its header bar the window's title bar.
    func testAPageByItselfStandsInAFrameWithItsHeaderBar() throws {
        try onUIThread {
            let host = GTKRenderer.running { TitledPage(title: "Alone") }
            let frame = try XCTUnwrap(host.window?.pageFrame)

            XCTAssertEqual(frame.chrome.title, "Alone")
            XCTAssertEqual(host.windowTitle, "Alone")
            XCTAssertTrue(gtk_widget_get_parent(frame.page.widget) != nil, "the page stands in the frame")
        }
    }

    /// The visible page's actions stand at its header bar's end in their order, the overflow's behind the
    /// bar's menu; choosing one runs its handler, and one that cannot be chosen runs nothing.
    func testThePagesActionsFollowTheirOrder() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Notes", actions: [
                        ToolbarItem("Delete").placement(.overflow).onClicked { heard.values.append("delete") },
                        ToolbarItem("Add").isEnabled(false).onClicked { heard.values.append("add") },
                        ToolbarItem("Save").onClicked { heard.values.append("save") },
                    ])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
            }
            let frame = try XCTUnwrap(host.views(GTKNavigationView.self).first?.frames.last)
            XCTAssertEqual(frame.buttons.map(\.text), ["Add", "Save"])
            XCTAssertEqual(frame.overflowButtons.map(\.text), ["Delete"])
            XCTAssertEqual(gtk_widget_get_sensitive(frame.buttons[0].widget), 0, "Add cannot be chosen")

            for button in frame.buttons + frame.overflowButtons where gtk_widget_get_sensitive(button.widget) != 0 {
                button.click()
            }
            host.runtime.pump.turn()
            XCTAssertEqual(heard.values, ["save", "delete"])
        }
    }

    /// An action with a picture stands on the header bar as an icon named by its title; one whose picture the
    /// application does not hold shows its title, and the overflow's menu shows titles.
    func testAnActionWithAPictureStandsAsAnIcon() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                TitledPage(title: "Notes", actions: [
                    ToolbarItem("Wide").icon("test_wide.png"),
                    ToolbarItem("Lost").icon("missing.png"),
                    ToolbarItem("Later").icon("test_wide.png").placement(.overflow),
                ])
            }
            let frame = try XCTUnwrap(host.window?.pageFrame)
            let wide = try XCTUnwrap(frame.buttons.first)
            let image = try XCTUnwrap(gtk_button_get_child(wide.widget.of(GtkButton.self)))

            XCTAssertEqual(g_type_name(UnsafeMutablePointer<GTypeInstance>(image.opaque).pointee.g_class.pointee.g_type)
                .map { String(cString: $0) }, "GtkImage")
            XCTAssertNotEqual(gtk_widget_has_css_class(wide.widget, "image-button"), 0)
            XCTAssertEqual(gtk_widget_get_tooltip_text(wide.widget).map { String(cString: $0) }, "Wide")
            XCTAssertEqual(frame.buttons.map(\.text), ["", "Lost"])
            XCTAssertEqual(frame.overflowButtons.map(\.text), ["Later"])
        }
    }

    /// A destructive action is libadwaita's destructive button on the header bar; in the overflow's flat menu its
    /// words take the theme's destructive colour, not the white that button writes on its red fill.
    func testADestructiveActionWearsTheThemesDestructiveColour() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                TitledPage(title: "Notes", actions: [
                    ToolbarItem("Remove").isDestructive(true),
                    ToolbarItem("Clear").isDestructive(true).placement(.overflow),
                    ToolbarItem("Later").placement(.overflow),
                ])
            }
            let frame = try XCTUnwrap(host.window?.pageFrame)
            let remove = try XCTUnwrap(frame.buttons.first)
            XCTAssertNotEqual(gtk_widget_has_css_class(remove.widget, "destructive-action"), 0)

            let colors = frame.overflowButtons.map { button in
                var color = GdkRGBA()
                gtk_widget_get_color(button.widget, &color)
                return color
            }
            XCTAssertEqual(colors.count, 2)
            XCTAssertGreaterThan(colors[0].red - max(colors[0].green, colors[0].blue), 0.3, "Clear's words are red")
            XCTAssertLessThan(abs(colors[1].red - colors[1].green), 0.1, "Later's words are the menu's own")
        }
    }

    /// A stack's bar colours paint the header bar of every page on it, and what stands on the bar.
    func testAStacksBarColoursPaintItsPagesHeaderBars() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Painted")
                } destination: { _ in
                    TitledPage(title: "Next")
                }
                .barBackgroundColor(Color("#FF0000"))
                .barForegroundColor(Color("#FFFFFF"))
            }
            let frame = try XCTUnwrap(host.views(GTKNavigationView.self).first?.frames.last)
            host.layOut()

            XCTAssertNotEqual(gtk_widget_has_css_class(frame.header, "stateui-bar-bFF0000FF-fFFFFFFFF"), 0)
            XCTAssertEqual(GTKTestHost.pixels(of: frame.header, at: [(4, 4)]), [0xFFFF_0000])
        }
    }

    /// Another kind of view made at a stack's root stands there as its page, shown and named; the first kind comes
    /// back the same way.
    func testAnotherViewAtAStacksRootIsShown() throws {
        try onUIThread {
            let searching = State(wrappedValue: false)
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    if searching.wrappedValue {
                        SearchingPage()
                    } else {
                        TitledPage(title: "Reader")
                    }
                } destination: { _ in TitledPage(title: "Next") }
            }
            let navigation = try XCTUnwrap(host.views(GTKNavigationView.self).first)
            XCTAssertEqual(navigation.visiblePageTitle, "Reader")

            searching.wrappedValue = true
            host.settle { navigation.visiblePageTitle == "Search" }
            XCTAssertEqual(navigation.visiblePageTitle, "Search")
            XCTAssertEqual(navigation.frames.map(\.chrome.title), ["Search"])
            XCTAssertNotNil(host.views(GTKTextFieldView.self).first.flatMap { gtk_widget_get_mapped($0.widget) != 0 ? $0 : nil },
                            "its title view shows")
            XCTAssertEqual(host.windowTitle, "Search")

            searching.wrappedValue = false
            host.settle { navigation.visiblePageTitle == "Reader" }
            XCTAssertEqual(navigation.frames.map(\.chrome.title), ["Reader"])
            XCTAssertEqual(host.windowTitle, "Reader")
        }
    }

    /// A page that refuses the way back offers none: the host's way back leaves it, as the bar shows no back button.
    func testAPageRefusingTheWayBackKeepsItsPlace() {
        onUIThread {
            let path = State(wrappedValue: [1])
            let host = GTKRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in
                    TitledPage(title: "Signed in", hidesBack: true)
                }
            }
            host.settle { host.windowTitle == "Signed in" }

            XCTAssertFalse(host.goBack(), "no way back")
            XCTAssertEqual(path.wrappedValue, [1])
        }
    }

    /// A tab that is a stack shows one bar, the stack's page's, the tabs beneath it: the tabs' frame shows none over
    /// it.
    func testATabThatIsAStackShowsOneBar() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                TabbedView([0, 1]) { tab in
                    if tab == 0 {
                        NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                            TitledPage(title: "Inbox")
                        } destination: { _ in TitledPage(title: "Message") }
                        .title("Mail")
                    } else {
                        TitledPage(title: "Settings")
                    }
                }
            }
            host.layOut()
            let window = try XCTUnwrap(host.window).widget
            let bars = { GTKTestHost.descendants(of: window).filter {
                GTKTestHost.holds($0, adw_header_bar_get_type()) && gtk_widget_get_mapped($0) != 0
                    && gtk_widget_get_height($0) > 0
            } }
            host.settle { bars().count == 1 }

            XCTAssertEqual(bars().count, 1, "the stack's page's bar alone")
            let switcher = try XCTUnwrap(host.views(GTKTabbedView.self).first?.switcher)
            XCTAssertNotEqual(gtk_widget_get_mapped(switcher.widget), 0, "the tabs beneath it")
        }
    }

    /// A sheet is libadwaita's dialog over the window, its page in a frame of its own; the user closing it - Escape,
    /// its close button - takes it off the modal stack, and the program's close tells nothing.
    func testASheetTheUserClosesLeavesTheModalStack() throws {
        try onUIThread {
            let sheets = State(wrappedValue: [1, 2])
            let host = GTKRenderer.running {
                ModalStack(sheets.projectedValue) {
                    TitledPage(title: "Beneath")
                } destination: { number in
                    TitledPage(title: "Sheet \(number)")
                }
            }
            let controller = try XCTUnwrap(host.windows.first)
            host.settle { controller.sheets.count == 2 }
            XCTAssertEqual(controller.sheets.map { $0.sheet.frame?.chrome.title }, ["Sheet 1", "Sheet 2"])
            let window = controller.window.widget.of(AdwApplicationWindow.self)
            XCTAssertTrue(adw_application_window_get_visible_dialog(window) == controller.sheets[1].sheet.dialog,
                          "the top sheet shows")

            // libadwaita says a dialog closed once its sheet has gone, which a window behind another, drawn no
            // frames, never gets to by itself: the close is told as libadwaita tells it.
            GTKTestHost.emit(OpaquePointer(controller.sheets[1].sheet.dialog), "closed")
            host.settle { sheets.wrappedValue == [1] }
            XCTAssertEqual(sheets.wrappedValue, [1], "the user's close")

            sheets.wrappedValue = []
            host.settle { controller.sheets.isEmpty }
            XCTAssertEqual(sheets.wrappedValue, [], "the program's close heard by nobody")
        }
    }

    /// A bar painted with no colour written for its words stands them light on a dark band and dark on a light one.
    func testABarsWordsFollowHowDarkItIs() throws {
        try onUIThread {
            for (band, words) in [("#000080", Color(red: 255, green: 255, blue: 255)), ("#FFFF00", Color(red: 0, green: 0, blue: 0))] {
                let host = GTKRenderer.running {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        TitledPage(title: "Painted")
                    } destination: { _ in TitledPage(title: "Next") }
                    .barBackgroundColor(Color(band))
                }
                let frame = try XCTUnwrap(host.views(GTKNavigationView.self).first?.frames.last)
                host.layOut()

                var color = GdkRGBA()
                gtk_widget_get_color(frame.header, &color)
                let shade = { (value: Float) in Int((value * 255).rounded()) }
                XCTAssertEqual(
                    Color(red: shade(color.red), green: shade(color.green), blue: shade(color.blue)), words, band)
            }
        }
    }

    /// A header bar takes the colours the window's page declares around the page it shows.
    func testAHeaderBarTakesTheColoursItsPathDeclares() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                ModalStack(State(wrappedValue: [Int]()).projectedValue) {
                    Label("under a painted bar")
                } destination: { _ in Label("Sheet") }
                .barBackgroundColor(Color("#00FF00"))
                .barForegroundColor(Color("#FFFFFF"))
            }
            let frame = try XCTUnwrap(host.window?.pageFrame)
            host.settle { gtk_widget_has_css_class(frame.header, "stateui-bar-b00FF00FF-fFFFFFFFF") != 0 }

            XCTAssertNotEqual(gtk_widget_has_css_class(frame.header, "stateui-bar-b00FF00FF-fFFFFFFFF"), 0)
        }
    }

    /// A page's title view stands at the middle of its header bar; a page pushed over it has its own title.
    func testAPagesTitleViewStandsInItsHeaderBar() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = GTKRenderer.running {
                NavigationStack(path.projectedValue) {
                    SearchingPage()
                } destination: { _ in
                    TitledPage(title: "Result")
                }
            }
            let navigation = try XCTUnwrap(host.views(GTKNavigationView.self).first)
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)
            let root = try XCTUnwrap(navigation.frames.first)
            XCTAssertTrue(root.chrome.titleView === field)
            XCTAssertTrue(adw_header_bar_get_title_widget(root.header.opaque) == field.widget)

            path.wrappedValue = [1]
            host.runtime.pump.turn()
            XCTAssertNil(navigation.frames.last?.chrome.titleView)
            XCTAssertEqual(navigation.frames.last?.chrome.title, "Result")
            XCTAssertTrue(adw_header_bar_get_title_widget(root.header.opaque) == field.widget, "still the root's")
        }
    }

    /// A page that hides its navigation bar shows no header bar.
    func testAPageWithoutANavigationBarShowsNoHeaderBar() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [1]).projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in
                    TitledPage(title: "Bare", actions: [ToolbarItem("Save")], hidesBar: true)
                }
            }
            let frame = try XCTUnwrap(host.views(GTKNavigationView.self).first?.frames.last)
            XCTAssertFalse(frame.chrome.showsBar)
            XCTAssertEqual(adw_toolbar_view_get_reveal_top_bars(frame.widget.opaque), 0)
        }
    }
}

/// A page with a title, maybe a log of its phases, the actions it puts on its header bar, and whether it hides its
/// navigation bar.
struct TitledPage: ContentView {
    let title: String
    var log: Received<String>? = nil
    var actions: [ToolbarItem] = []
    var hidesBar = false
    var hidesBack = false

    @Environment private var page: PageSession

    var content: some View {
        let log = self.log
        let title = self.title
        let page = self.page

        return Label(title)
            .toolbar { actions }
            .onCreated {
                page.title = title
                if hidesBar { page.hasNavigationBar = false }
                if hidesBack { page.hasBackButton = false }
            }
            .onChanged(page.phase) { log?.values.append("\(title) \(page.phase)") }
    }
}

/// A page whose title view is a search field.
private struct SearchingPage: ContentView {
    @Environment private var page: PageSession
    @State private var query = ""

    var content: some View {
        let page = self.page
        let query = $query
        return Label("Results")
            .titleView { TextField(query).placeholder("Search") }
            .onCreated { page.title = "Search" }
    }
}
