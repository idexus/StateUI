// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import XCTest

final class AndroidPagesTests: XCTestCase {
    static var allTests: [(String, (AndroidPagesTests) -> () throws -> Void)] {
        [
            ("testADrawerStandsAtTheEdgeTheLanguageStartsFrom", testADrawerStandsAtTheEdgeTheLanguageStartsFrom),
            ("testAStackShowsItsTopPageUnderItsBarAndGoesBack", testAStackShowsItsTopPageUnderItsBarAndGoesBack),
            ("testTabsOnAStackNameTheBarByTheirOwnTitle", testTabsOnAStackNameTheBarByTheirOwnTitle),
            ("testWordsOnAPaintedBarFollowHowDarkItIs", testWordsOnAPaintedBarFollowHowDarkItIs),
            ("testABarsColourTravelsOnTheDisplaysFrames", testABarsColourTravelsOnTheDisplaysFrames),
            ("testAPushAndAPopAreHeardByThePagesInOrder", testAPushAndAPopAreHeardByThePagesInOrder),
            ("testTheBarOpensTheSidebarAndBackClosesIt", testTheBarOpensTheSidebarAndBackClosesIt),
            ("testALayoutWhileTheDrawerSlidesLeavesItSliding", testALayoutWhileTheDrawerSlidesLeavesItSliding),
            ("testASidebarWithNoPictureOpensFromTheMenuGlyph", testASidebarWithNoPictureOpensFromTheMenuGlyph),
            ("testAClosedDrawerStandsInvisible", testAClosedDrawerStandsInvisible),
            ("testADrawerUnderAClearWindowStandsOnASurfaceOfItsOwn", testADrawerUnderAClearWindowStandsOnASurfaceOfItsOwn),
            ("testATabChosenShowsItsPageAndSaysSo", testATabChosenShowsItsPageAndSaysSo),
            ("testTheRowMarksTheTabShown", testTheRowMarksTheTabShown),
            ("testAPagesToolbarItemsAreTheBarsActions", testAPagesToolbarItemsAreTheBarsActions),
            ("testALeadingGroupStandsFirstAmongTheActions", testALeadingGroupStandsFirstAmongTheActions),
            ("testTheBarsActionsStandInItsWordsColour", testTheBarsActionsStandInItsWordsColour),
            ("testAPagesTitleViewStandsInTheBarInPlaceOfItsTitle", testAPagesTitleViewStandsInTheBarInPlaceOfItsTitle),
            ("testAStackAndItsPagesSayHowTheBarAndThePageLook", testAStackAndItsPagesSayHowTheBarAndThePageLook),
            ("testTabsOfStacksOnAStackStandUnderOneBar", testTabsOfStacksOnAStackStandUnderOneBar),
            ("testATabsAndAnActionsPicturesStandAtTheIconSize", testATabsAndAnActionsPicturesStandAtTheIconSize),
            ("testAModalStackPresentsOverThePageAndBackTakesItDown", testAModalStackPresentsOverThePageAndBackTakesItDown),
            ("testThePageUnderPagesTheProgramTakesDownShowsAgain", testThePageUnderPagesTheProgramTakesDownShowsAgain),
            ("testAnArrangementTheWindowShowsInsteadAppears", testAnArrangementTheWindowShowsInsteadAppears),
            ("testTheWindowsOverlayStandsOverItsPagesAndLetsATouchBesideItThrough", testTheWindowsOverlayStandsOverItsPagesAndLetsATouchBesideItThrough),
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
            host.runtime.pump.turn()
            XCTAssertEqual(navigation.bar.content.title, "Detail 7")
            XCTAssertEqual(navigation.bar.content.navigation, .back)
            XCTAssertEqual(navigation.heldViews().count, 2, "the bar and the top page")

            XCTAssertTrue(host.goBack())
            XCTAssertEqual(path.wrappedValue, [])
            XCTAssertEqual(navigation.bar.content.title, "Root")
        }
    }

    /// Tabs pushed onto a stack are its last place and name the bar by their own title - never by what they show:
    /// their pages name their tabs alone.
    func testTabsOnAStackNameTheBarByTheirOwnTitle() throws {
        try onMainActor {
            let path = State(wrappedValue: [Int]())
            let host = AndroidRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Items and Cards")
                } destination: { _ in
                    TabView([1, 2]) { number in TitledPage(title: "Example \(number)") }.title("ItemsView")
                }
            }
            host.layOut()
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.title, "Items and Cards")

            path.wrappedValue = [1]
            host.runtime.pump.turn()
            XCTAssertEqual(navigation.bar.content.title, "ItemsView")
        }
    }

    /// Words on a bar the tree paints stand light on a dark bar and dark on a light one, where the tree writes no
    /// colour for them (`BandWords`).
    func testWordsOnAPaintedBarFollowHowDarkItIs() throws {
        try onMainActor {
            let dark = State(wrappedValue: true)
            let (navy, yellow) = (Color(red: 0, green: 0, blue: 128), Color(red: 255, green: 230, blue: 0))
            let host = AndroidRenderer.running(reducesMotion: true) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in TitledPage(title: "Pushed") }
                    .barBackgroundColor(dark.wrappedValue ? navy : yellow)
            }
            host.layOut()
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.foreground, .color(red: 255, green: 255, blue: 255, alpha: 255))

            dark.wrappedValue = false
            host.runtime.pump.turn()
            XCTAssertEqual(navigation.bar.content.foreground, .color(red: 0, green: 0, blue: 0, alpha: 255))
        }
    }

    /// A bar's colour the tree changes travels on the display's frames, where nothing arranges the stack: the bar
    /// shows a colour on the way, then lands on the new one.
    func testABarsColourTravelsOnTheDisplaysFrames() throws {
        try onMainActor {
            let first = State(wrappedValue: true)
            let clock = TestClock()
            let host = AndroidRenderer.running(clock: clock) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in TitledPage(title: "Pushed") }
                    .barBackgroundColor(first.wrappedValue ? Color(red: 200, green: 0, blue: 0) : Color(red: 0, green: 0, blue: 200))
            }
            host.layOut()
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            let (start, end) = (
                HostValue.color(red: 200, green: 0, blue: 0, alpha: 255), HostValue.color(red: 0, green: 0, blue: 200, alpha: 255))
            XCTAssertEqual(navigation.bar.content.background, start)

            first.wrappedValue = false
            host.runtime.pump.turn()
            clock.now = 100
            host.frame()
            let midway = navigation.bar.content.background
            XCTAssertNotEqual(midway, start, "the bar moved on a frame")
            XCTAssertNotEqual(midway, end, "the bar is on its way")

            clock.now = 10_000
            host.frame()
            XCTAssertEqual(navigation.bar.content.background, end)
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

    /// A sidebar in a language written right to left is a drawer at the right edge, the edge that language starts
    /// from.
    func testADrawerStandsAtTheEdgeTheLanguageStartsFrom() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    TitledPage(title: "Home")
                }
            }
            let hebrew = try XCTUnwrap(HostLocaleInfo(words: ["he", "IL", "he-IL", "Asia/Jerusalem", "1", "0", "1", "1"]))
            let english = try XCTUnwrap(HostLocaleInfo(words: ["en", "GB", "en-GB", "Europe/London", "1", "1", "1", "0"]))
            defer { host.runtime.environmentChanged { host.runtime.core.setLocaleInfo(english) } }
            host.runtime.environmentChanged { host.runtime.core.setLocaleInfo(hebrew) }
            host.layOut()
            let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
            XCTAssertTrue(split.overlays, "a narrow window's sidebar is a drawer")
            XCTAssertEqual(
                split.drawer.frame.x + split.drawer.frame.width, split.frame.width, "the drawer stands at the right edge")
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

    /// The drawer slides open: a layout while it slides - opening it changes the bar, which lays the page out
    /// again - leaves it sliding rather than putting it where it ends. The test's frames never come, so a
    /// drawer still sliding stands where it started, off the leading edge.
    func testALayoutWhileTheDrawerSlidesLeavesItSliding() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                SplitView(State(wrappedValue: false).projectedValue) {
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
            let drawer = try XCTUnwrap(split.heldViews().last)
            let closed = Java.callFloat(drawer.reference, TestJava.getTranslationX)
            XCTAssertLessThan(closed, 0, "a closed drawer stands off the leading edge")

            try XCTUnwrap(host.views(AndroidNavigationView.self).first).bar.clicked()
            host.runtime.pump.turn()
            Java.call(split.reference, JavaAPI.requestLayout)
            host.layOut()

            XCTAssertTrue(split.isPresented)
            XCTAssertEqual(Java.callFloat(drawer.reference, TestJava.getTranslationX), closed)
        }
    }

    /// A sidebar page with no picture still gives the detail's bar its button: Android's menu glyph.
    func testASidebarWithNoPictureOpensFromTheMenuGlyph() throws {
        try onMainActor {
            let host = AndroidRenderer.running { drawerOverStack(sidebar: TitledPage(title: "Menu")) }
            host.layOut()
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)

            XCTAssertEqual(navigation.bar.content.navigation, .sidebar(nil))
            let glyph = Java.frame { Java.callObject(navigation.bar.reference, TestJava.getNavigationIcon) != nil }
            XCTAssertTrue(glyph, "the bar shows a button to open the sidebar")
        }
    }

    /// A drawer over the detail stands on a surface of its own - the theme's floating one - never on the window's: a
    /// window painted clear leaves the drawer opaque, the detail hidden behind a sidebar page that paints nothing.
    func testADrawerUnderAClearWindowStandsOnASurfaceOfItsOwn() throws {
        try onMainActor {
            stateUIUseApp(OneWindowApplication {
                WindowPainted(colour: .transparent) {
                    drawerOverStack(sidebar: TitledPage(title: "Menu", icon: "test_dot.png"))
                }
            })
            // In the activity's window, which the window's colour paints; its theme's back comes back after.
            let host = AndroidRenderer.start(context: TestContext.window, root: TestJava.root(), density: 2)
            defer {
                Java.callStatic(
                    JavaAPI.environment, JavaAPI.setWindowBackground, .object(TestContext.window.reference), .int(0),
                    .bool(false))
            }
            host.layOut()
            let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
            let drawer = try XCTUnwrap(split.heldViews().last)
            try XCTUnwrap(host.views(AndroidNavigationView.self).first).bar.clicked()

            let colour = Java.callStaticLong(JavaAPI.views, AndroidDriver.sidebarColour, .object(drawer.reference))
            XCTAssertNotEqual(colour, Int64.min, "the drawer stands on a surface")
            XCTAssertEqual(UInt32(truncatingIfNeeded: colour) >> 24, 0xFF, "an opaque one, whatever the window is")
        }
    }

    /// A closed drawer holds nothing the keyboard or assistive technology reaches: it stands invisible, shows as it
    /// slides open, and stands invisible again once it has slid away.
    func testAClosedDrawerStandsInvisible() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                drawerOverStack(sidebar: TitledPage(title: "Menu", icon: "test_dot.png"))
            }
            host.layOut()
            let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
            let drawer = try XCTUnwrap(split.heldViews().last)
            let visibility = { Java.callInt(drawer.reference, TestJava.getVisibility) }
            XCTAssertEqual(visibility(), ViewConstants.invisible)

            try XCTUnwrap(host.views(AndroidNavigationView.self).first).bar.clicked()
            XCTAssertEqual(visibility(), ViewConstants.visible, "shown as it slides open")

            XCTAssertTrue(host.goBack())
            XCTAssertEqual(visibility(), ViewConstants.visible, "shown while it slides away")
            TestWindow.run(for: AndroidSplitView.slide + 250)
            XCTAssertEqual(visibility(), ViewConstants.invisible)
        }
    }

    /// The tabs' titles along the bottom; a tab the user chooses shows its page and lands on the selection.
    func testATabChosenShowsItsPageAndSaysSo() throws {
        try onMainActor {
            let tab = State(wrappedValue: 0)
            let host = AndroidRenderer.running {
                TabView([0, 1]) { number in
                    TitledPage(title: "Tab \(number)")
                }
                .selection(tab.projectedValue)
            }
            host.layOut()
            let tabs = try XCTUnwrap(host.views(AndroidTabView.self).first)
            let pages = host.views(AndroidSingleChildView.self)
            XCTAssertTrue(tabs.heldViews().first === pages[0])

            tabs.selectByUser(1)
            XCTAssertEqual(tab.wrappedValue, 1)
            XCTAssertTrue(tabs.heldViews().first === pages[1])
        }
    }

    /// A tab asked for past the last shows the last there is, and the row marks that one - no choice of the user's.
    func testTheRowMarksTheTabShown() throws {
        try onMainActor {
            let tab = State(wrappedValue: 0)
            let host = AndroidRenderer.running {
                TabView([0, 1, 2]) { number in TitledPage(title: "Tab \(number)") }
                    .selection(tab.projectedValue)
            }
            host.layOut()
            let tabs = try XCTUnwrap(host.views(AndroidTabView.self).first)
            let pages = host.views(AndroidSingleChildView.self)
            var row = AndroidTabView.Row()
            row.tabs = (0..<3).map { AndroidTabView.Tab(title: "Tab \($0)", picture: nil) }

            tabs.show(row, requested: 5)
            host.layOut()
            XCTAssertEqual(tabs.markedTab, 2, "the row marks the tab shown")
            XCTAssertTrue(tabs.heldViews().first === pages.last, "the last there is")
            XCTAssertEqual(tab.wrappedValue, 0, "and no choice of the user's heard")
        }
    }

    /// What a page puts on the bar: its actions in their order, the overflow's last in a group of their own, each with its
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
                        ToolbarItem("Add").icon("test_wide.png").isEnabled(false)
                            .onClicked { heard.values.append("add") },
                        ToolbarItem("Save").icon("test_wide.png").onClicked { heard.values.append("save") },
                    ])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
            }
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.actions.map(\.onBar), [true, true, false])

            let menu = JavaObject(try XCTUnwrap(Java.callObject(navigation.bar.reference, TestMenus.getMenu)))
            XCTAssertEqual(TestMenus.describe(menu), "Add (off) (dimmed picture), Save (picture) | Delete (red)")
            for words in ["Add", "Save", "Delete"] { TestMenus.choose(menu, words) }
            host.runtime.pump.turn()
            XCTAssertEqual(heard.values, ["save", "delete"])
        }
    }
}

extension AndroidPagesTests {
    /// A bar with no leading edge beside its navigation button: a leading group the stack declares stands first
    /// among the actions, the page's own after it.
    func testALeadingGroupStandsFirstAmongTheActions() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Notes", actions: [ToolbarItem("Save")])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
                .toolbar(.leading) { ToolbarItem("Filter") }
            }
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.actions.map(\.text), ["Filter", "Save"])
        }
    }

    /// The actions standing on a painted bar take their words from the bar's theme - light on a dark bar, dark on a
    /// light one - as Android's own bars do; their pictures take the bar's words' colour itself. A bar painted
    /// again in the other shade is made again in its theme.
    func testTheBarsActionsStandInItsWordsColour() throws {
        try onMainActor {
            let dark = State(wrappedValue: true)
            let host = AndroidRenderer.running(reducesMotion: true) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Notes", actions: [
                        ToolbarItem("Scan"),
                        ToolbarItem("Save").icon("test_wide.png"),
                    ])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
                .barBackgroundColor(dark.wrappedValue ? .purple : .yellow)
                .barForegroundColor(dark.wrappedValue ? .white : .navy)
            }
            host.layOut()
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            let onDark = TestMenus.onBar(navigation.bar)

            dark.wrappedValue = false
            host.runtime.pump.turn()
            host.layOut()

            XCTAssertEqual(onDark, "Scan light, picture #ffffffff")
            XCTAssertEqual(TestMenus.onBar(navigation.bar), "Scan dark, picture #ff000080")
        }
    }

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
            host.runtime.pump.turn()
            XCTAssertNil(bar.titleView)
            XCTAssertEqual(Java.callInt(bar.reference, TestJava.indexOfChild, .object(field.reference)), -1)
            XCTAssertEqual(Self.title(of: bar), "Result")

            XCTAssertTrue(host.goBack())
            host.runtime.pump.turn()
            XCTAssertTrue(bar.titleView === field)
            XCTAssertEqual(Self.title(of: bar), "")
        }
    }

    /// The stack colours its bar; a page says whether the bar shows and whether it has a way back, and what
    /// its ground is and how far in its content stands.
    func testAStackAndItsPagesSayHowTheBarAndThePageLook() throws {
        try onMainActor {
            let path = State(wrappedValue: [Int]())
            let host = AndroidRenderer.running {
                NavigationStack(path.projectedValue) {
                    FurnishedPage(title: "Root")
                } destination: { number in
                    FurnishedPage(title: "Page \(number)", showsBackButton: number != 1, showsNavigationBar: number != 2)
                }
                .barBackgroundColor(.red)
                .barForegroundColor(.white)
            }
            host.layOut()
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(Self.colour(of: navigation.bar), 0xFFFF_0000)
            XCTAssertEqual(navigation.bar.content.foreground.flatMap(AndroidView.argb), Int32(bitPattern: 0xFFFF_FFFF))
            let page = try XCTUnwrap(host.views(AndroidSingleChildView.self).first)
            XCTAssertEqual(Self.colour(of: page), 0xFF00_00FF)
            let words = try XCTUnwrap(host.views(AndroidTextView.self).first)
            XCTAssertEqual(Java.callInt(words.reference, TestJava.getLeft), 16, "8 points in, at two pixels a point")

            path.wrappedValue = [1]
            host.runtime.pump.turn()
            XCTAssertEqual(navigation.bar.content.navigation, .none, "a page without a back button")
            path.wrappedValue = [1, 2]
            host.runtime.pump.turn()
            XCTAssertFalse(navigation.showsBar, "a page without a navigation bar")
            XCTAssertTrue(host.goBack(), "the system's back takes a page hiding its bar back")
            host.runtime.pump.turn()
            XCTAssertEqual(path.wrappedValue, [1])
        }
    }

    /// Tabs whose chosen tab is a stack, pushed on a stack, stand under that tab's bar alone: the outer stack's bar
    /// hides over them and shows again over its own page.
    func testTabsOfStacksOnAStackStandUnderOneBar() throws {
        try onMainActor {
            let path = State(wrappedValue: [1])
            let host = AndroidRenderer.running {
                NavigationStack(path.projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in
                    TabView([0, 1]) { tab in
                        NavigationStack(State(wrappedValue: [Int]()).projectedValue) { TitledPage(title: "Tab \(tab)") }
                            destination: { number in TitledPage(title: "Pushed \(number)") }
                    }
                }
            }
            host.layOut()
            let stacks = host.views(AndroidNavigationView.self)
            let (outer, tab) = (try XCTUnwrap(stacks.first), try XCTUnwrap(stacks.dropFirst().first))
            XCTAssertFalse(outer.showsBar, "no bar laid over the tabs")
            XCTAssertTrue(tab.showsBar, "the tab's own")

            path.wrappedValue = []
            host.runtime.pump.turn()
            XCTAssertTrue(outer.showsBar, "the root's bar")
        }
    }

    /// A tab's picture and a bar action's stand at Android's icon size, 24 dp tall, as wide as their shape -
    /// a picture of 6 by 4 pixels and one of 40 by 20 points alike.
    func testATabsAndAnActionsPicturesStandAtTheIconSize() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                TabView([0, 1]) { number in
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        TitledPage(
                            title: "Tab \(number)",
                            actions: [ToolbarItem("Dot").icon("test_dot.png"), ToolbarItem("Wide").icon("test_wide.png")])
                    } destination: { _ in
                        TitledPage(title: "Pushed")
                    }
                    .icon(number == 0 ? "test_dot.png" : "test_wide.png")
                }
            }
            host.layOut()
            let row = try XCTUnwrap(host.views(AndroidTabView.self).first?.heldViews().last)
            let bar = try XCTUnwrap(host.views(AndroidNavigationView.self).first).bar
            let tall = TestPictures.pixels(24)
            let icons = "\(Int((Double(tall) * 1.5).rounded()))x\(tall), \(tall * 2)x\(tall)"

            XCTAssertEqual(TestPictures.tabs(row), icons)
            XCTAssertEqual(TestPictures.menu(JavaObject(try XCTUnwrap(Java.callObject(bar.reference, TestMenus.getMenu)))), icons)
        }
    }

    /// The colour a view's background is painted in.
    @MainActor
    private static func colour(of view: AndroidView) -> UInt32 {
        Java.frame {
            Java.callObject(view.reference, TestJava.getBackground).map {
                UInt32(bitPattern: Java.callInt($0, TestJava.getColor))
            } ?? 0
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
            let host = AndroidRenderer.running(reducesMotion: true) { sheetsPage(sheets, log: log) }
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 1)

            log.values = []
            sheets.wrappedValue = [1]
            host.runtime.pump.turn()
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
            let host = AndroidRenderer.running(reducesMotion: true) { sheetsPage(sheets, log: log) }
            sheets.wrappedValue = [1, 2]
            host.runtime.pump.turn()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 3)

            log.values = []
            sheets.wrappedValue = [1]
            host.runtime.pump.turn()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 2)
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Sheet 1 appearing"])

            log.values = []
            sheets.wrappedValue = []
            host.runtime.pump.turn()
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
            host.runtime.pump.turn()
            XCTAssertEqual(host.views(AndroidTextView.self).map(\.text), ["Root"])
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Root appearing"])
        }
    }

    /// The inspector docked in the window is its overlay: over the page and over a page presented after it,
    /// taking no touch beside its panel, and gone once the inspector closes.
    func testTheWindowsOverlayStandsOverItsPagesAndLetsATouchBesideItThrough() throws {
        try onMainActor {
            let sheets = State(wrappedValue: [Int]())
            let windows = Received<WindowSession>()
            let host = AndroidRenderer.running(reducesMotion: true) { sheetsPage(sheets, windows: windows) }
            let session = try XCTUnwrap(windows.values.last)
            defer { Inspector.close(in: session) }
            host.layOut()

            Inspector.open(in: session)
            host.runtime.pump.turn()
            host.layOut()
            let overlay = try XCTUnwrap((host.runtime.tree.root?.first(type: .overlay)?.native as? AndroidElement)?.view, "no overlay view")
            let root = host.root.reference
            XCTAssertEqual(Java.callInt(root, TestJava.getChildCount), 2, "the page, and the overlay over it")
            XCTAssertEqual(Java.callInt(root, TestJava.indexOfChild, .object(overlay.reference)), 1)
            XCTAssertEqual(overlay.frame.width, 1080)
            XCTAssertEqual(overlay.frame.height, 1920)
            XCTAssertFalse(overlay.touched(x: 540, y: 100), "the overlay took a touch beside its panel")

            sheets.wrappedValue = [1]
            host.runtime.pump.turn()
            XCTAssertEqual(Java.callInt(root, TestJava.getChildCount), 3)
            XCTAssertEqual(Java.callInt(root, TestJava.indexOfChild, .object(overlay.reference)), 2, "under the sheet")

            Inspector.close(in: session)
            host.runtime.pump.turn()
            XCTAssertEqual(Java.callInt(root, TestJava.getChildCount), 2, "the page and the sheet")
            XCTAssertEqual(Java.callInt(root, TestJava.indexOfChild, .object(overlay.reference)), -1)
        }
    }
}

/// A page on a blue ground with its words 8 points in, saying whether its bar shows and has a way back.
private struct FurnishedPage: View {
    let title: String
    var showsBackButton = true
    var showsNavigationBar = true

    var body: some View {
        VStack { Text(title) }
            .padding(8)
            .title(title)
            .pageBackground(.blue)
            .showsBackButton(showsBackButton)
            .showsNavigationBar(showsNavigationBar)
    }
}

/// A page whose search field stands in its bar in place of its title.
private struct SearchingPage: View {
    @State private var query = ""

    var body: some View {
        let query = $query
        return Text("Results")
            .titleView { SearchField(query).placeholder("Search") }
            .title("Search")
    }
}

/// A page under the sheets one state lists, telling its window - the window's page, a modal stack.
@MainActor
private func sheetsPage(
    _ sheets: State<[Int]>, log: Received<String> = Received(), windows: Received<WindowSession> = Received()
) -> ModalStack {
    ModalStack(sheets.projectedValue) {
        ScenePage(log: log, windows: windows)
    } destination: { number in
        TitledPage(title: "Sheet \(number)", log: log)
    }
}

/// A page that tells its window as it comes.
private struct ScenePage: View {
    let log: Received<String>
    let windows: Received<WindowSession>

    @Environment(\.window) private var window

    var body: some View {
        let (windows, window) = (self.windows, self.window)
        return TitledPage(title: "Page", log: log).onCreated { windows.values.append(window) }
    }
}

/// A split whose sidebar slides over a stack, as on a phone.
@MainActor
private func drawerOverStack(sidebar: some View) -> some View {
    SplitView(State(wrappedValue: false).projectedValue) {
        sidebar
    } detail: {
        NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
            TitledPage(title: "Home")
        } destination: { _ in
            TitledPage(title: "Deeper")
        }
    }
}

/// `content` in a window painted `colour`.
private struct WindowPainted<Content: View>: View {
    @Environment(\.window) private var window
    let colour: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        let (window, colour) = (self.window, self.colour)
        return content().onCreated { window.background = .color(colour) }
    }
}

/// A page that names itself, and writes each phase it hears into `log`.
private struct TitledPage: View {
    let title: String
    var icon: ImageSource? = nil
    var log: Received<String>? = nil
    var actions: [ToolbarItem] = []

    var body: some View {
        let words = Text(title).toolbar { actions }.title(title)
        return (icon.map { words.icon($0) } ?? words).loggingPhases(log, as: title)
    }
}
