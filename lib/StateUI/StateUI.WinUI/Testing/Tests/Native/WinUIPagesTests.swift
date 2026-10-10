// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

final class WinUIPagesTests: XCTestCase {
    /// A detail page beside the open sidebar is laid out in the room beside it, however the sidebar opened: a
    /// scroller's content there is as wide as the scroller.
    func testADetailBesideTheSidebarTakesTheRoomBesideIt() throws {
        try onUIThread {
            let open = State(wrappedValue: false)
            let host = WinUIRenderer.running(room: WinUITestHost.wideRoom) {
                SplitView(open.projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    ScrollView {
                        VStack { HStack { Text("row") } }
                    }
                }
            }
            let window = try XCTUnwrap(host.window)
            host.settle { open.wrappedValue }
            window.titleBar.chose(-2)
            host.runtime.pump.turn()
            window.titleBar.chose(-2)
            host.runtime.pump.turn()
            host.layOut()

            let scroller = try XCTUnwrap(host.views(WinUIScrollView.self).first)
            let row = try XCTUnwrap(host.views(WinUIStackView.self).last)
            XCTAssertTrue(open.wrappedValue)
            XCTAssertGreaterThan(scroller.frame.width, 0)
            XCTAssertEqual(row.frame.width, scroller.frame.width, "the row across the scroller's content")
        }
    }

    /// The sidebar's page stands in the pane's height from the first start: a footer under a scroller of many rows
    /// stands inside the window. WinUI lays the pane's content out once in a row sized to what it holds, before the
    /// relay gives that row the pane's height; a StateUI layout inside kept the places of that first layout, and the
    /// footer stood below the window until the pane was closed and opened again.
    func testTheSidebarsFooterStandsInTheWindowFromTheFirstStart() throws {
        try onUIThread {
            let open = State(wrappedValue: true)
            let host = WinUIRenderer.running(room: WinUITestHost.wideRoom) {
                SplitView(open.projectedValue) {
                    Grid {
                        ScrollView {
                            VStack { ForEach(0..<60, id: \.self) { Text("row \($0)") } }
                        }
                        Text("footer").gridRow(1)
                    }
                    .rows(.fill, .auto)
                } detail: {
                    Text("detail")
                }
            }
            for _ in 0..<20 { host.step() }
            host.layOut()

            let split = try XCTUnwrap(host.views(WinUISplitView.self).first)
            let footer = try XCTUnwrap(host.views(WinUITextView.self).first { $0.text == "footer" })
            XCTAssertGreaterThan(footer.frame.height, 0)
            XCTAssertLessThanOrEqual(
                footer.origin.y + footer.frame.height, split.origin.y + split.frame.height + 1,
                "the footer stands below the window")
        }
    }

    /// A row of tabs marks the tab the view shows as the tabs change, and what the program changes is no choice of the
    /// user's.
    func testTheRowMarksTheTabShownAsTheTabsChange() throws {
        try onUIThread {
            let tabs = State(wrappedValue: [0, 1, 2])
            let tab = State(wrappedValue: 2)
            let host = WinUIRenderer.running {
                TabView(tabs.wrappedValue) { number in Text("Tab \(number)") }.selection(tab.projectedValue)
            }
            let tabbed = try XCTUnwrap(host.views(WinUITabView.self).first)
            let row: WinUIView = tabbed.tabsShownByWindow ? try XCTUnwrap(host.window).tabRow : tabbed.row
            XCTAssertEqual(Self.selected(row), 2)

            tabs.wrappedValue = [0, 1]
            host.runtime.pump.turn()
            let now = try XCTUnwrap(host.views(WinUITabView.self).first)
            XCTAssertEqual(now.tabs.count, 2)
            XCTAssertEqual(Self.selected(row), now.shownIndex, "the row marks the tab shown")
            XCTAssertEqual(tab.wrappedValue, 2, "and no choice of the user's heard")
        }
    }

    /// A tab's picture stands as tall as the theme's tab icons and as wide as its shape makes it - an SVG too, which
    /// tells WinUI a size of thousands of pixels: nothing in the tab's template bounds its icon.
    func testATabsPictureStandsAsTallAsTheThemesTabIcons() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                TabView([0, 1]) { tab in
                    if tab == 0 {
                        Text("Wide").title("Wide").icon("test_wide.png")
                    } else {
                        Text("Plain").title("Plain")
                    }
                }
            }
            let tabbed = try XCTUnwrap(host.views(WinUITabView.self).first)
            let row: WinUIView = tabbed.tabsShownByWindow ? try XCTUnwrap(host.window).tabRow : tabbed.row
            host.settle { Self.words(row, "tabIconSizes") == "32x16;" }
            XCTAssertEqual(Self.words(row, "tabIconSizes"), "32x16;", "40 by 20 drawn 16 tall; no picture beside it")
        }
    }

    /// Tabs pushed onto a stack are its last place and name the window by their own title, in the chrome and in the
    /// window's own name - never by what they show: their pages name their tabs alone.
    func testTabsOnAStackNameTheWindowByTheirOwnTitle() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = WinUIRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Items and Cards")
                } destination: { _ in
                    TabView([1, 2]) { number in TitledPage(title: "Example \(number)") }.title("ItemsView")
                }
            }
            let window = try XCTUnwrap(host.window)
            host.settle { Self.words(window.titleBar, "title") == "Items and Cards" }

            path.wrappedValue = [1]
            host.settle { host.views(WinUITabView.self).first?.tabs.map(\.title) == ["Example 1", "Example 2"] }
            XCTAssertEqual(
                host.views(WinUITabView.self).first?.tabs.map(\.title), ["Example 1", "Example 2"], "pushed")
            XCTAssertEqual(Self.words(window.titleBar, "title"), "ItemsView", "the chrome's title")
            var bytes = [CChar](repeating: 0, count: 64)
            let length = stateui_winui_window_system_title(window.handle, &bytes, Int32(bytes.count))
            XCTAssertEqual(
                String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self),
                "ItemsView", "the window's own name")
        }
    }

    /// What the relay reads of `view` as `what`.
    @MainActor
    private static func words(_ view: WinUIView, _ what: String) -> String {
        words(view.handle, what)
    }

    /// What the relay reads of the object `handle` holds, as `what` names it; empty for nothing.
    @MainActor
    private static func words(_ handle: StateUIObjectRef, _ what: String) -> String {
        var bytes = [CChar](repeating: 0, count: 128)
        let length = stateui_winui_read(handle, what, &bytes, Int32(bytes.count))
        return String(decoding: bytes.prefix(Int(max(length, 0))).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// The place of the tab a row marks; -1 for none.
    @MainActor
    private static func selected(_ row: WinUIView) -> Int {
        var bytes = [CChar](repeating: 0, count: 16)
        let length = stateui_winui_read(row.handle, "selected", &bytes, Int32(bytes.count))
        let words = String(decoding: bytes.prefix(Int(max(length, 0))).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return Double(words).map { Int($0) } ?? -1
    }

    /// Words on a bar the tree paints stand light on a dark bar and dark on a light one, where the tree writes no
    /// colour for them (`BandWords`) - the title, the way back and the actions alike.
    func testWordsOnAPaintedBarFollowHowDarkItIs() throws {
        try onUIThread {
            let dark = State(wrappedValue: true)
            let (navy, yellow) = (Color(red: 0, green: 0, blue: 128), Color(red: 255, green: 230, blue: 0))
            let host = WinUIRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    Text("Root")
                } destination: { _ in Text("Pushed") }
                    .barBackgroundColor(dark.wrappedValue ? navy : yellow)
            }
            let bar = try XCTUnwrap(host.window).titleBar
            XCTAssertEqual(stateui_winui_title_bar_words(bar.handle), 1, "light on navy")

            dark.wrappedValue = false
            host.settle { stateui_winui_title_bar_words(bar.handle) == 2 }
            XCTAssertEqual(stateui_winui_title_bar_words(bar.handle), 2, "dark on yellow, once the colour travelled")
        }
    }

    /// The menu bar is one of the window's bars: it wears their colour, its menus' words the bars' words - the colour
    /// written, else light on a dark bar - and the platform's own again where nothing is declared.
    func testTheMenuBarWearsTheBarsColours() throws {
        try onUIThread {
            let painted = State(wrappedValue: true)
            let (navy, yellow) = (Color(red: 0, green: 0, blue: 128), Color(red: 255, green: 230, blue: 0))
            let host = WinUIRenderer.running {
                let stack = NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    Text("Root")
                        .menuBar { Menu("File") { MenuItem("Save") } }
                } destination: { _ in Text("Pushed") }
                return painted.wrappedValue ? stack.barBackgroundColor(navy).barForegroundColor(yellow) : stack
            }
            let window = try XCTUnwrap(host.window)
            host.settle { window.menuBarStands }
            XCTAssertEqual(Self.words(window.menuBar, "background"), "#FF000080", "the bars' colour")
            XCTAssertEqual(Self.words(window.menuBar, "itemForeground"), "#FFFFE600", "the bars' words")
            XCTAssertEqual(Self.words(window.menuBar, "theme"), "2", "the dark theme of a dark bar")

            painted.wrappedValue = false
            host.settle { Self.words(window.menuBar, "theme") == "0" }
            XCTAssertNotEqual(Self.words(window.menuBar, "background"), "#FF000080", "the platform's own again")
            XCTAssertEqual(Self.words(window.menuBar, "itemForeground"), "")
        }
    }

    /// The pane holding a sidebar wears the sidebar page's background, so no room WinUI keeps around the page in it
    /// shows the window's backdrop.
    func testTheSidebarsPaneWearsItsPagesBackground() throws {
        try onUIThread {
            let tone = State(wrappedValue: Color(red: 0, green: 0, blue: 128))
            let host = WinUIRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    TonedSidebar(tone: tone.wrappedValue)
                } detail: {
                    Text("detail")
                }
            }
            let split = try XCTUnwrap(host.views(WinUISplitView.self).first)
            host.settle { Self.words(split.sidebar, "paneBackground") == "#FF000080" }
            XCTAssertEqual(Self.words(split.sidebar, "paneBackground"), "#FF000080")

            tone.wrappedValue = Color(red: 128, green: 0, blue: 0)
            host.settle { Self.words(split.sidebar, "paneBackground") == "#FF800000" }
            XCTAssertEqual(Self.words(split.sidebar, "paneBackground"), "#FF800000", "and follows it")
        }
    }

    /// A window whose background the application writes shows it behind the detail as beside the sidebar and under
    /// the bars: the card WinUI lays over the detail is clear, its edge the theme's divider. A window left to the
    /// platform keeps WinUI's card.
    func testTheDetailShowsTheWindowsWrittenBackground() throws {
        try onUIThread {
            let written = State(wrappedValue: Material?.some(.blur(.ultraThick)))
            let host = WinUIRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    Text("sidebar")
                } detail: {
                    WindowSessionPage(key: "\(String(describing: written.wrappedValue))") {
                        $0.background = written.wrappedValue
                    }
                }
            }
            let window = try XCTUnwrap(host.window)
            host.settle { Self.words(window.handle, "detailCard") == "#00000000" }
            XCTAssertEqual(Self.words(window.handle, "detailCard"), "#00000000")
            XCTAssertNotEqual(Self.words(window.handle, "divider"), "")
            XCTAssertEqual(Self.words(window.handle, "detailEdge"), Self.words(window.handle, "divider"), "its edge")

            written.wrappedValue = nil
            host.settle { Self.words(window.handle, "detailCard") == "" }
            XCTAssertEqual(Self.words(window.handle, "detailCard"), "", "a window left to the platform keeps WinUI's")
            XCTAssertEqual(Self.words(window.handle, "detailEdge"), "")
        }
    }

    /// The sidebar page stands at the top of the split view: no border of the navigation view's and no margin of its
    /// pane's stands above it, as a band of another tone between the window's bar and the page.
    func testTheSidebarPageStandsAtTheSplitViewsTop() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    TonedSidebar(tone: Color(red: 0, green: 0, blue: 128))
                } detail: {
                    Text("detail")
                }
            }
            let split = try XCTUnwrap(host.views(WinUISplitView.self).first)
            host.settle { host.views(WinUITextView.self).contains { $0.text == "sidebar" && $0.frame.height > 0 } }
            host.layOut()
            let sidebar = try XCTUnwrap(host.views(WinUITextView.self).first { $0.text == "sidebar" })
            XCTAssertEqual(sidebar.origin.y, split.origin.y, accuracy: 0.5, "the page at the split view's top")
        }
    }

    /// The actions on a painted bar stand in its words' colour - the one written, else light on a dark bar and dark
    /// on a light one - not in the theme's.
    func testTheBarsActionsStandInItsWordsColour() throws {
        try onUIThread {
            let navy = Color(red: 0, green: 0, blue: 128)
            for (written, words) in [(Color(red: 255, green: 230, blue: 0) as Color?, "#FFFFE600"), (nil, "#FFFFFFFF")] {
                let host = WinUIRenderer.running {
                    let stack = NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        TitledPage(title: "Notes", actions: [ToolbarItem("Scan")])
                    } destination: { _ in Text("Pushed") }
                        .barBackgroundColor(navy)
                    return written.map { stack.barForegroundColor($0) } ?? stack
                }
                let bar = try XCTUnwrap(host.window).titleBar
                host.settle { Self.words(bar, "actions") == "|Scan|" }
                XCTAssertEqual(Self.words(bar, "actionWords"), words, "written \(String(describing: written))")
            }
        }
    }

    /// A destructive action stands in the critical colour of its bar's own theme - lighter on a dark bar - whatever
    /// colour the bar's words take: its words' brush follows the theme, which a brush looked up once would not.
    func testADestructiveActionStandsInTheCriticalColourOfItsBarsTheme() throws {
        try onUIThread {
            var reds: [(red: UInt32, green: UInt32, blue: UInt32)] = []
            for background in [Color(red: 0, green: 0, blue: 128), Color(red: 255, green: 255, blue: 224)] {
                let host = WinUIRenderer.running {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        TitledPage(
                            title: "Notes", actions: [ToolbarItem("Scan"), ToolbarItem("Delete").isDestructive(true)])
                    } destination: { _ in Text("Pushed") }
                        .barBackgroundColor(background)
                        .barForegroundColor(Color(red: 255, green: 230, blue: 0))
                }
                let bar = try XCTUnwrap(host.window).titleBar
                host.settle { Self.words(bar, "actions") == "|Scan;Delete|" }
                let words = Self.words(bar, "actionWords").split(separator: ";").map(String.init)
                XCTAssertEqual(words.first, "#FFFFE600", "an action stands in the bar's words' colour")
                let argb = try XCTUnwrap(words.count == 2 ? UInt32(words[1].dropFirst(), radix: 16) : nil)
                let red = (red: argb >> 16 & 0xFF, green: argb >> 8 & 0xFF, blue: argb & 0xFF)
                XCTAssertNotEqual(words[1], "#FFFFE600", "the destructive one keeps its own colour")
                XCTAssertTrue(red.red > red.green && red.red > red.blue, "the destructive one is red: \(words[1])")
                reds.append(red)
            }
            XCTAssertGreaterThan(reds[0].green, reds[1].green, "lighter on the dark bar than on the light one")
        }
    }

    /// The keys a window takes - Alt+Left, the Back key, Escape - show in no tip: its content holds them, and a tip
    /// saying them would stand under the pointer over everything the window shows.
    func testTheKeysAWindowTakesShowInNoTip() throws {
        try onUIThread {
            let host = WinUIRenderer.running { VStack { Text("Content") } }
            XCTAssertFalse(stateui_winui_window_shows_keys(try XCTUnwrap(host.window).handle))
        }
    }

    /// The chrome keeps the window's own buttons their room once, at the scale the window stands at: WinUI's title
    /// bar keeps it in pixels as though they were DIPs, which at 200% stands its actions a caption's width short of
    /// the bar's end.
    func testTheChromeKeepsTheCaptionButtonsTheirRoomOnce() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Home", actions: [ToolbarItem("Inspector")])
                } destination: { _ in Text("Pushed") }
            }
            let bar = try XCTUnwrap(host.window).titleBar
            var (kept, room) = (-1.0, 0.0)
            host.settle {
                stateui_winui_title_bar_caption_room(bar.handle, &kept, &room)
                return kept >= 0 && room > 0
            }
            XCTAssertGreaterThan(room, 0, "the window has its own buttons")
            XCTAssertEqual(kept, room, accuracy: 0.5, "the room kept is theirs")
        }
    }

    /// A sidebar taller than the window scrolls: its scroller stands in the room the pane has, shorter than what it
    /// holds.
    func testASidebarTallerThanTheWindowScrolls() throws {
        try onUIThread {
            let host = WinUIRenderer.running(room: WinUITestHost.wideRoom) {
                SplitView(State(wrappedValue: true).projectedValue) {
                    ScrollView {
                        VStack { ForEach(Array(0..<100), id: \.self) { number in Text("Row \(number)") } }
                    }
                } detail: {
                    Text("Detail")
                }
            }
            host.layOut()
            let scroller = try XCTUnwrap(host.views(WinUIScrollView.self).first)
            let rows = try XCTUnwrap(host.views(WinUIStackView.self).first)
            host.settle { scroller.frame.height > 0 && scroller.frame.height < rows.frame.height }

            XCTAssertGreaterThan(scroller.frame.height, 0)
            XCTAssertLessThan(scroller.frame.height, rows.frame.height, "the rows run past the scroller: it scrolls")
        }
    }

    /// A tabbed view in a split view's detail stands its tabs across the detail, beside the sidebar.
    func testATabbedDetailStandsItsTabsAcrossTheDetail() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    TabView([0, 1]) { number in TitledPage(title: "Tab \(number)") }
                }
            }
            let window = try XCTUnwrap(host.window)
            let split = try XCTUnwrap(host.views(WinUISplitView.self).first)
            XCTAssertFalse(window.tabsStandInWindow)
            XCTAssertTrue(split.detailRow === window.tabRow)
        }
    }

    /// A tabbed detail under a modal stack - the window's page, its sheets over it - stands its tabs across the
    /// detail as it does with no modal stack.
    func testATabbedDetailUnderAModalStackStandsItsTabsAcrossTheDetail() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                ModalStack(State(wrappedValue: [Int]()).projectedValue) {
                    SplitView(State(wrappedValue: true).projectedValue) {
                        TitledPage(title: "Menu")
                    } detail: {
                        TabView([0, 1]) { number in TitledPage(title: "Tab \(number)") }
                    }
                } destination: { number in TitledPage(title: "Sheet \(number)") }
            }
            let window = try XCTUnwrap(host.window)
            let split = try XCTUnwrap(host.views(WinUISplitView.self).first)
            XCTAssertTrue(split.detailRow === window.tabRow)
        }
    }

    /// A page that asks for the focus as it appears holds it in a new arrangement of the window - a split view in
    /// place of the stack a sign-in stood on - though the field that held it leaves with that stack.
    func testAPageInANewArrangementHoldsTheFocusItAskedFor() throws {
        try onUIThread {
            let signedIn = State(wrappedValue: false)
            let host = WinUIRenderer.running { Self.signIn(signedIn) }
            let typed = try XCTUnwrap(host.views(WinUITextFieldView.self).first)
            XCTAssertTrue(stateui_winui_focus(typed.handle, true), "the sign-in's field holds the focus")

            signedIn.wrappedValue = true
            for _ in 0..<20 { host.step() }

            let field = try XCTUnwrap(host.views(WinUITextFieldView.self).first)
            XCTAssertFalse(field === typed, "the sign-in has left")
            XCTAssertTrue(stateui_winui_focused(field.handle), "the field the page aimed at holds the focus")
        }
    }

    /// A closed sidebar holds nothing the keyboard or assistive technology reaches, beside the detail or over it:
    /// its button refuses the focus until the sidebar opens, and again once it has closed.
    func testAClosedSidebarHoldsNothingTheKeyboardReaches() throws {
        try onUIThread {
            for room in [WinUITestHost.room, WinUITestHost.wideRoom] {
                let open = State(wrappedValue: false)
                let host = WinUIRenderer.running(room: room) {
                    SplitView(open.projectedValue) {
                        Button("Sign out")
                    } detail: {
                        Text("Detail")
                    }
                }
                let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)
                let takes = { stateui_winui_focus(button.handle, true) }
                open.wrappedValue = false
                for _ in 0..<50 { host.step() }
                XCTAssertFalse(takes(), "closed, \(room.width) wide")

                open.wrappedValue = true
                for _ in 0..<50 { host.step() }
                XCTAssertTrue(takes(), "open, \(room.width) wide")

                open.wrappedValue = false
                for _ in 0..<50 { host.step() }
                XCTAssertFalse(takes(), "closed again, \(room.width) wide")
            }
        }
    }

    /// Tab walks what the window shows and comes back: the chrome's places nothing is written in are no stops.
    func testTabStopsOnlyWhereSomethingShows() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TextField(State(wrappedValue: "").projectedValue)
                } destination: { _ in Text("Pushed") }
            }
            let field = try XCTUnwrap(host.views(WinUITextFieldView.self).first)
            XCTAssertTrue(stateui_winui_focus(field.handle, true))

            var stops: [String] = []
            repeat {
                var bytes = [CChar](repeating: 0, count: 128)
                let length = stateui_winui_tab(field.handle, &bytes, Int32(bytes.count))
                stops.append(String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self))
            } while stops.count < 8 && !stateui_winui_focused(field.handle)
            XCTAssertTrue(stateui_winui_focused(field.handle), "Tab comes back to the field: \(stops)")
            XCTAssertFalse(stops.contains("Microsoft.UI.Xaml.Controls.ContentControl"), "\(stops)")
        }
    }

    /// A sign-in's field on a stack, then a split view whose stack's page aims at its field.
    @ViewBuilder
    @MainActor
    private static func signIn(_ signedIn: State<Bool>) -> some View {
        if signedIn.wrappedValue {
            SplitView(State(wrappedValue: false).projectedValue) {
                Text("Menu")
            } detail: {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    AimedFieldPage()
                } destination: { _ in Text("Pushed") }
            }
        } else {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                TextField(State(wrappedValue: "").projectedValue)
            } destination: { _ in Text("Pushed") }
        }
    }
}

/// A page that puts the focus in its field as it appears.
private struct AimedFieldPage: View {
    @Aim(TextField.self) private var field

    var body: some View {
        let field = self.field
        return VStack {
            TextField(State(wrappedValue: "").projectedValue).aim(field)
            Button("Below")
        }
        .onAppearing(gate: .ignoreWhileRunning) { try await field.focus() }
    }
}

/// A page with a title, maybe a log of its phases, the actions it puts on the window's chrome, and whether it hides
/// its navigation bar.
private struct TitledPage: View {
    let title: String
    var log: Received<String>? = nil
    var actions: [ToolbarItem] = []
    var hidesBar = false

    var body: some View {
        Text(title)
            .toolbar { actions }
            .title(title)
            .showsNavigationBar(!hidesBar)
            .loggingPhases(log, as: title)
    }
}

/// A sidebar page in `tone`.
private struct TonedSidebar: View {
    let tone: Color

    var body: some View {
        Text("sidebar").pageBackground(tone)
    }
}
