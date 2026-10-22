// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import StateUIConformance
import XCTest

@MainActor
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

            // The popped page hears it disappears as it leaves the tree, then the page beneath comes back.
            log.values = []
            XCTAssertTrue(host.goBack())
            XCTAssertEqual(log.values, ["Pushed disappearing", "Root appearing", "Root navigatedTo"])
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

    /// GNOME keeps no Edit menu of its own: one a page joins holds the field's undoing, clipboard and selection, and
    /// they act on the words the user typed into, though the menu takes the focus as it opens.
    func testTheEditMenuActsOnTheWordsTypedInto() throws {
        try onUIThread {
            let words = State(wrappedValue: "hello")
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    VStack {
                        TextField(words.projectedValue)
                        Button("Other")
                    }
                    .menuBar { Menu("Edit") { MenuItem("Find") }.id(StandardMenu.edit) }
                    .title("Notes")
                } destination: { _ in
                    Text("Note")
                }
            }
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)
            gtk_widget_grab_focus(field.widget)
            host.settle { false }
            gtk_widget_grab_focus(host.views(GTKButtonView.self)[0].widget)
            host.settle { false }
            XCTAssertNotNil(host.window?.typed, "the window keeps the words typed into")
            let main = try XCTUnwrap(host.views(GTKNavigationView.self).first?.frames.last?.mainMenu)
            @MainActor func choose(_ command: EditCommand) throws {
                let named = main.menu.edits[command]
                let name = try XCTUnwrap(named, "the Edit menu holds \(command)")
                XCTAssertNotEqual(
                    gtk_widget_activate_action_variant(main.button, main.menu.group + "." + name, nil), 0,
                    "the menu's action \(name) runs")
            }

            XCTAssertEqual(Set(main.menu.edits.values).count, EditCommand.allCases.count, "each entry its own action")
            XCTAssertEqual(main.menu.items.count, 1, "the application's Find, apart from them")
            XCTAssertNil(main.menu.items.keys.first { main.menu.edits.values.contains($0) })

            gtk_editable_select_region(field.widget.opaque, 0, 0)
            try choose(.selectAll)
            try choose(.cut)
            host.settle { words.wrappedValue.isEmpty }
            XCTAssertEqual(words.wrappedValue, "", "the words cut")
            try choose(.paste)
            host.settle { words.wrappedValue == "hello" }
            XCTAssertEqual(words.wrappedValue, "hello", "the clipboard's words pasted back")
            try choose(.undo)
            host.settle { words.wrappedValue.isEmpty }
            XCTAssertEqual(words.wrappedValue, "", "the paste undone")
        }
    }

    /// The overflow's menu stands before the main menu at the bar's end, whichever of them changed last.
    func testTheOverflowStandsBeforeTheMainMenu() throws {
        try onUIThread {
            let more = State(wrappedValue: false)
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    Text("Notes")
                        .toolbar {
                            ToolbarItem("Later").placement(.overflow)
                            if more.wrappedValue { ToolbarItem("Sooner").placement(.overflow) }
                        }
                        .menuBar { Menu("File") { MenuItem("Open") } }
                        .title("Notes")
                } destination: { _ in
                    Text("Note")
                }
            }
            more.wrappedValue = true
            host.runtime.pump.turn()

            let frame = try XCTUnwrap(host.views(GTKNavigationView.self).first?.frames.last)
            XCTAssertEqual(frame.overflowButtons.count, 2)
            XCTAssertEqual(gtk_widget_get_last_child(frame.endBox), frame.mainMenu?.button, "the main menu stands last")
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
    /// words take the theme's destructive color, not the white that button writes on its red fill.
    func testADestructiveActionWearsTheThemesDestructiveColor() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                TitledPage(title: "Notes", actions: [
                    ToolbarItem("Remove").role(.destructive),
                    ToolbarItem("Clear").role(.destructive).placement(.overflow),
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

    /// A stack's bar colors paint the header bar of every page on it, and what stands on the bar.
    func testAStacksBarColorsPaintItsPagesHeaderBars() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Painted")
                } destination: { _ in
                    TitledPage(title: "Next")
                }
                .barBackgroundColor(Color(hex: 0xFF0000))
                .barForegroundColor(Color(hex: 0xFFFFFF))
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

    /// The switcher shows the tabs in the tree's order: a tab added between two stands between them, not last.
    func testTheSwitcherShowsTheTabsInTheTreesOrder() throws {
        try onUIThread {
            let tabs = State(wrappedValue: ["A", "C"])
            let host = GTKRenderer.running {
                TabView(tabs.wrappedValue) { name in TitledPage(title: name).title(name) }
            }
            let view = try XCTUnwrap(host.views(GTKTabView.self).first)
            let titles = { Self.switcherTitles(view) }
            host.settle { titles() == ["A", "C"] }

            tabs.wrappedValue = ["A", "B", "C"]
            host.settle { titles().count == 3 }
            XCTAssertEqual(titles(), ["A", "B", "C"])

            tabs.wrappedValue = ["C", "A"]
            host.settle { titles().count == 2 }
            XCTAssertEqual(titles(), ["C", "A"])
        }
    }

    /// The titles of the pages the tab view's stack holds, in the order its switcher shows them.
    @MainActor
    private static func switcherTitles(_ view: GTKTabView) -> [String] {
        guard let stack = gtk_stack_switcher_get_stack(view.switcher.widget.opaque) else { return [] }
        let pages = gtk_stack_get_pages(stack)!
        defer { g_object_unref(UnsafeMutableRawPointer(pages)) }
        return (0..<g_list_model_get_n_items(pages)).compactMap { index in
            guard let page = g_list_model_get_item(pages, index) else { return nil }
            defer { g_object_unref(page) }
            return gtk_stack_page_get_title(OpaquePointer(page)).map { String(cString: $0) }
        }
    }

    /// A tab that is a stack shows one bar, the stack's page's, the tabs beneath it: the tabs' frame shows none over
    /// it.
    func testATabThatIsAStackShowsOneBar() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                TabView([0, 1]) { tab in
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
            let switcher = try XCTUnwrap(host.views(GTKTabView.self).first?.switcher)
            XCTAssertNotEqual(gtk_widget_get_mapped(switcher.widget), 0, "the tabs beneath it")
        }
    }

    /// A sheet asks libadwaita's dialog for its page's size - here the least, its words few - and one holding a
    /// stack, whose pages come and go, the standard size, held within the window.
    func testASheetAsksTheSizeOfItsPageAndAStackTheStandard() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) { Text("A note") }
            }
            let controller = try XCTUnwrap(host.windows.first)
            host.settle { controller.sheets.count == 1 }
            let dialog = try XCTUnwrap(controller.sheets.first?.sheet.dialog)
            XCTAssertEqual([adw_dialog_get_content_width(dialog), adw_dialog_get_content_height(dialog)], [320, 180])

            let stacked = GTKRenderer.running {
                Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) { Text("Root") } destination: { _ in Text("Next") }
                }
            }
            let stackController = try XCTUnwrap(stacked.windows.first)
            stacked.settle { stackController.sheets.count == 1 }
            let stackDialog = try XCTUnwrap(stackController.sheets.first?.sheet.dialog)
            let window = stackController.window.widget
            XCTAssertEqual(
                [adw_dialog_get_content_width(stackDialog), adw_dialog_get_content_height(stackDialog)],
                [min(560, gtk_widget_get_width(window) - 48), min(480, gtk_widget_get_height(window) - 48)])
        }
    }

    /// A sheet is libadwaita's dialog over the window, its page in a frame of its own; the user closing it - Escape,
    /// its close button - writes false onto its state, and the program's close tells nothing.
    func testASheetTheUserClosesWritesItsState() throws {
        try onUIThread {
            let (first, second) = (State(wrappedValue: true), State(wrappedValue: true))
            let host = GTKRenderer.running {
                TitledPage(title: "Beneath")
                    .sheet(isPresented: first.projectedValue) {
                        TitledPage(title: "Sheet 1")
                            .sheet(isPresented: second.projectedValue) { TitledPage(title: "Sheet 2") }
                    }
            }
            let controller = try XCTUnwrap(host.windows.first)
            host.settle { controller.sheets.count == 2 }
            XCTAssertEqual(controller.sheets.map { String(cString: adw_dialog_get_title($0.sheet.dialog)) }, ["Sheet 1", "Sheet 2"])
            let window = controller.window.widget.of(AdwApplicationWindow.self)
            XCTAssertTrue(adw_application_window_get_visible_dialog(window) == controller.sheets[1].sheet.dialog,
                          "the top sheet shows")

            // libadwaita says a dialog closed once its sheet has gone, which a window behind another, drawn no
            // frames, never gets to by itself: the close is told as libadwaita tells it.
            GTKTestHost.emit(OpaquePointer(controller.sheets[1].sheet.dialog), "closed")
            host.settle { !second.wrappedValue }
            XCTAssertEqual([first.wrappedValue, second.wrappedValue], [true, false], "the user's close")

            first.wrappedValue = false
            host.settle { controller.sheets.isEmpty }
            XCTAssertEqual([first.wrappedValue, second.wrappedValue], [false, false], "the program's close heard by nobody")
        }
    }

    /// A window the tree closes takes its sheets with it - libadwaita, asked to close a window a dialog stands over,
    /// closes the dialog alone and keeps the window.
    func testAWindowTheTreeClosesTakesItsSheets() throws {
        try onUIThread {
            let host = GTKRenderer.running(application: { SheetedApplication() })
            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { host.windows.count == 2 && host.windows[1].sheets.count == 1 }
            let sheeted = try XCTUnwrap(host.windows.last?.window.widget)
            g_object_ref(UnsafeMutableRawPointer(sheeted))
            defer { g_object_unref(UnsafeMutableRawPointer(sheeted)) }
            XCTAssertNotEqual(gtk_widget_get_visible(sheeted), 0, "shown, its sheet over it")

            host.views(GTKButtonView.self)[1].click()
            host.settle { host.windows.count == 1 && gtk_widget_get_visible(sheeted) == 0 }
            XCTAssertEqual(gtk_widget_get_visible(sheeted), 0, "the window closed, its sheet with it")
        }
    }

    /// A window the tree closes while a question stands over it closes, the question with it.
    func testAWindowTheTreeClosesTakesItsQuestion() throws {
        try onUIThread {
            let host = GTKRenderer.running(application: { SheetedApplication(asks: true) })
            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { host.windows.count == 2 && host.visibleDialog(over: host.windows[1].window) != nil }
            let asking = try XCTUnwrap(host.windows.last?.window.widget)
            g_object_ref(UnsafeMutableRawPointer(asking))
            defer { g_object_unref(UnsafeMutableRawPointer(asking)) }

            host.views(GTKButtonView.self)[1].click()
            host.settle { host.windows.count == 1 && gtk_widget_get_visible(asking) == 0 }
            XCTAssertEqual(gtk_widget_get_visible(asking), 0, "the window closed, its question with it")
        }
    }

    /// A sheet beneath another given another page comes over it, as a page presented anew: the sheets from the
    /// change up leave and come again, so the last shown is the one on top.
    func testASheetGivenAnotherPageComesOverTheOthers() throws {
        try onUIThread {
            let (note, shows) = (State<Int?>(wrappedValue: 1), State(wrappedValue: false))
            let host = GTKRenderer.running {
                VStack {
                    Text("Notes").sheet(item: note.projectedValue) { number in TitledPage(title: "Sheet \(number)") }
                    Text("More").sheet(isPresented: shows.projectedValue) { TitledPage(title: "Sheet 2") }
                }
            }
            let controller = try XCTUnwrap(host.windows.first)
            host.settle { controller.sheets.count == 1 }
            shows.wrappedValue = true
            host.settle { controller.sheets.count == 2 }

            note.wrappedValue = 3
            host.settle { controller.sheets.map { String(cString: adw_dialog_get_title($0.sheet.dialog)) } == ["Sheet 2", "Sheet 3"] }

            XCTAssertEqual(controller.sheets.map { String(cString: adw_dialog_get_title($0.sheet.dialog)) }, ["Sheet 2", "Sheet 3"])
            let window = controller.window.widget.of(AdwApplicationWindow.self)
            XCTAssertTrue(adw_application_window_get_visible_dialog(window) == controller.sheets[1].sheet.dialog,
                          "the last shown on top")
        }
    }

    /// A bar painted with no color written for its words stands them light on a dark band and dark on a light one.
    func testABarsWordsFollowHowDarkItIs() throws {
        try onUIThread {
            let bands: [(band: UInt32, words: Color)] = [(0x000080, .white), (0xFFFF00, .black)]
            for (band, words) in bands {
                let host = GTKRenderer.running {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        TitledPage(title: "Painted")
                    } destination: { _ in TitledPage(title: "Next") }
                    .barBackgroundColor(Color(hex: band))
                }
                let frame = try XCTUnwrap(host.views(GTKNavigationView.self).first?.frames.last)
                host.layOut()

                var color = GdkRGBA()
                gtk_widget_get_color(frame.header, &color)
                let shade = { (value: Float) in Int((value * 255).rounded()) }
                XCTAssertEqual(
                    Color(red: shade(color.red), green: shade(color.green), blue: shade(color.blue)), words,
                    "0x\(String(band, radix: 16))")
            }
        }
    }

    /// A header bar takes the colors the stack around the page it shows declares.
    func testAHeaderBarTakesTheColorsItsPathDeclares() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    Text("under a painted bar")
                } destination: { _ in Text("Next") }
                .barBackgroundColor(Color(hex: 0x00FF00))
                .barForegroundColor(Color(hex: 0xFFFFFF))
            }
            let frame = try XCTUnwrap(host.views(GTKNavigationView.self).first?.frames.last)
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
struct TitledPage: View {
    let title: String
    var log: Received<String>? = nil
    var actions: [ToolbarItem] = []
    var hidesBar = false
    var hidesBack = false

    var body: some View {
        Text(title)
            .toolbar { actions }
            .title(title)
            .showsNavigationBar(!hidesBar)
            .showsBackButton(!hidesBack)
            .loggingPhases(log, as: title)
    }
}

/// A page whose title view is a search field.
private struct SearchingPage: View {
    @State private var query = ""

    var body: some View {
        let query = $query
        return Text("Results")
            .titleView { TextField(query).placeholder("Search") }
            .title("Search")
    }
}

/// An application whose page opens a window showing a sheet - or, `asks`, a question - and closes it.
private struct SheetedApplication: Application {
    var asks = false

    var body: some Scene { SheetedScene(asks: asks) }
}

private struct SheetedScene: Scene {
    let asks: Bool

    var body: some Scene {
        WindowGroup { SheetedOpeningPage() }
        Window(WindowType("pages.sheeted")) {
            if asks {
                AskingSheetedPage()
            } else {
                SheetedPage()
            }
        }
    }
}

/// The sheeted window's page asking the user over its own window as it is made.
private struct AskingSheetedPage: View {
    @Environment(\.window) private var window

    var body: some View {
        let window = self.window
        return Text("Asking").onCreated { _ = try await window.confirm("Keep?", message: "", accept: "Keep", cancel: "Drop") }
    }
}

private struct SheetedOpeningPage: View {
    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return VStack {
            Button("Open").onClicked(gate: .ignoreWhileRunning) {
                try await application.openWindow(WindowType("pages.sheeted"))
            }
            Button("Close").onClicked(gate: .ignoreWhileRunning) {
                try await application.closeWindow(WindowType("pages.sheeted"))
            }
        }
    }
}

private struct SheetedPage: View {
    @State private var shows = true

    var body: some View {
        TitledPage(title: "Beneath").sheet(isPresented: $shows) { TitledPage(title: "Sheet 1") }
    }
}
