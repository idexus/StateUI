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
            ("testAPageStandsOnTheThemesGroundWhereTheWindowPaintsNone", testAPageStandsOnTheThemesGroundWhereTheWindowPaintsNone),
            ("testAPageStandsOnItsWindowsColor", testAPageStandsOnItsWindowsColor),
            ("testTabsOnAStackNameTheBarByTheirOwnTitle", testTabsOnAStackNameTheBarByTheirOwnTitle),
            ("testWordsOnAPaintedBarFollowHowDarkItIs", testWordsOnAPaintedBarFollowHowDarkItIs),
            ("testTheStatusBarsWordsFollowThePaintedBarUnderThem", testTheStatusBarsWordsFollowThePaintedBarUnderThem),
            ("testABarsColorTravelsOnTheDisplaysFrames", testABarsColorTravelsOnTheDisplaysFrames),
            ("testAPushAndAPopAreHeardByThePagesInOrder", testAPushAndAPopAreHeardByThePagesInOrder),
            ("testTheBarOpensTheSidebarAndBackClosesIt", testTheBarOpensTheSidebarAndBackClosesIt),
            ("testTheSidebarsOwnBarHidesItAndTheDetailsShowsIt", testTheSidebarsOwnBarHidesItAndTheDetailsShowsIt),
            ("testTheSidebarBesideTheDetailMovesWithIt", testTheSidebarBesideTheDetailMovesWithIt),
            ("testAPushedPageKeepsTheSidebarsToggleBeforeTheWayBack", testAPushedPageKeepsTheSidebarsToggleBeforeTheWayBack),
            ("testAPushedPageShowsOnlyTheWayBackWhereTheSplitViewOffersNoToggle", testAPushedPageShowsOnlyTheWayBackWhereTheSplitViewOffersNoToggle),
            ("testTheSidebarsBarStandsAsHighAsTheDetails", testTheSidebarsBarStandsAsHighAsTheDetails),
            ("testTheSidebarBesideTheDetailStandsApartByALine", testTheSidebarBesideTheDetailStandsApartByALine),
            ("testALayoutWhileTheDrawerSlidesLeavesItSliding", testALayoutWhileTheDrawerSlidesLeavesItSliding),
            ("testASidebarWithNoPictureOpensFromTheMenuGlyph", testASidebarWithNoPictureOpensFromTheMenuGlyph),
            ("testAClosedDrawerStandsInvisible", testAClosedDrawerStandsInvisible),
            ("testADrawerUnderAClearWindowStandsOnASurfaceOfItsOwn", testADrawerUnderAClearWindowStandsOnASurfaceOfItsOwn),
            ("testATabChosenShowsItsPageAndSaysSo", testATabChosenShowsItsPageAndSaysSo),
            ("testTheRowMarksTheTabShown", testTheRowMarksTheTabShown),
            ("testAPagesToolbarItemsAreTheBarsActions", testAPagesToolbarItemsAreTheBarsActions),
            ("testALeadingGroupStandsFirstAmongTheActions", testALeadingGroupStandsFirstAmongTheActions),
            ("testTheBarsActionsStandInItsWordsColor", testTheBarsActionsStandInItsWordsColor),
            ("testAPagesTitleViewStandsInTheBarInPlaceOfItsTitle", testAPagesTitleViewStandsInTheBarInPlaceOfItsTitle),
            ("testAStackAndItsPagesSayHowTheBarAndThePageLook", testAStackAndItsPagesSayHowTheBarAndThePageLook),
            ("testTabsOfStacksOnAStackStandUnderOneBar", testTabsOfStacksOnAStackStandUnderOneBar),
            ("testATabsAndAnActionsPicturesStandAtTheIconSize", testATabsAndAnActionsPicturesStandAtTheIconSize),
            ("testASheetPresentsOverThePageAndBackTakesItDown", testASheetPresentsOverThePageAndBackTakesItDown),
            ("testASheetStandsOnACardAsLargeAsItsPageInAWideWindow", testASheetStandsOnACardAsLargeAsItsPageInAWideWindow),
            ("testAPageStandsClearOfTheSystemsBarsUnlessItSaysSo", testAPageStandsClearOfTheSystemsBarsUnlessItSaysSo),
            ("testARootDrawnEdgeToEdgeHearsTheStatusBar", testARootDrawnEdgeToEdgeHearsTheStatusBar),
            ("testAStacksBarReachesUnderTheStatusBar", testAStacksBarReachesUnderTheStatusBar),
            ("testAPagesScrollerUnderTheNavigationBarKeepsItsLastRowClear", testAPagesScrollerUnderTheNavigationBarKeepsItsLastRowClear),
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

    /// A page stands on an opaque ground - every page of a stack, the one pushed too - so a page sliding over another
    /// hides it: the theme's where the window paints no color.
    func testAPageStandsOnTheThemesGroundWhereTheWindowPaintsNone() throws {
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
            path.wrappedValue.append(1)
            host.runtime.pump.turn()

            let pages = try XCTUnwrap(host.runtime.tree.root).pages
            XCTAssertEqual(pages.count, 2)
            for page in pages {
                let ground = try XCTUnwrap(PageGround.color(of: page), "\(page.id) stands on nothing")
                XCTAssertEqual(ground >> 24, 0xFF, "\(page.id) stands on an opaque ground")
            }
        }
    }

    /// A page that paints no background of its own stands on its window's color.
    func testAPageStandsOnItsWindowsColor() throws {
        try onMainActor {
            stateUIUseApp(OneWindowApplication {
                WindowPainted(color: Color(red: 51, green: 102, blue: 153)) {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        TitledPage(title: "Root")
                    } destination: { number in
                        TitledPage(title: "Detail \(number)")
                    }
                }
            })
            let host = AndroidRenderer.start(context: TestContext.window, root: TestJava.root(), density: 2)
            defer {
                Java.callStatic(
                    JavaAPI.environment, JavaAPI.setWindowBackground, .object(TestContext.window.reference), .int(0),
                    .bool(false))
            }
            host.layOut()

            let page = try XCTUnwrap(host.runtime.tree.root?.first(type: .window)?.pages.last)
            XCTAssertEqual(PageGround.color(of: page), 0xFF33_6699)
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
    /// color for them (`BandWords`).
    func testWordsOnAPaintedBarFollowHowDarkItIs() throws {
        try onMainActor {
            let dark = State(wrappedValue: true)
            let (navy, yellow) = (Color(red: 0, green: 0, blue: 128), Color(red: 255, green: 230, blue: 0))
            let host = AndroidRenderer.running(reducesMotion: true) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in TitledPage(title: "Pushed") }
                    .barBackground(dark.wrappedValue ? navy : yellow)
            }
            host.layOut()
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.foreground, .color(red: 255, green: 255, blue: 255, alpha: 255))

            dark.wrappedValue = false
            host.runtime.pump.turn()
            XCTAssertEqual(navigation.bar.content.foreground, .color(red: 0, green: 0, blue: 0, alpha: 255))
        }
    }

    /// The status bar's words over the window's painted bar follow it as the bar's own do: light over a dark bar,
    /// dark over a light one, the theme's where the tree paints none.
    func testTheStatusBarsWordsFollowThePaintedBarUnderThem() throws {
        onMainActor {
            let navy = State(wrappedValue: true)
            let host = AndroidRenderer.running(reducesMotion: true) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in TitledPage(title: "Pushed") }
                    .barBackground(navy.wrappedValue ? Color(red: 0, green: 0, blue: 128) : Color(red: 255, green: 230, blue: 0))
            }
            host.layOut()
            XCTAssertEqual(host.statusWords, .light, "over a dark bar")

            navy.wrappedValue = false
            host.runtime.pump.turn()
            XCTAssertEqual(host.statusWords, .dark, "over a light one")

            let plain = AndroidRenderer.running(reducesMotion: true) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in TitledPage(title: "Pushed") }
            }
            plain.layOut()
            XCTAssertEqual(plain.statusWords, .platform, "the theme's over a bar the tree paints none of")
        }
    }

    /// A bar's color the tree changes travels on the display's frames, where nothing arranges the stack: the bar
    /// shows a color on the way, then lands on the new one.
    func testABarsColorTravelsOnTheDisplaysFrames() throws {
        try onMainActor {
            let first = State(wrappedValue: true)
            let clock = TestClock()
            let host = AndroidRenderer.running(clock: clock) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Root")
                } destination: { _ in TitledPage(title: "Pushed") }
                    .barBackground(first.wrappedValue ? Color(red: 200, green: 0, blue: 0) : Color(red: 0, green: 0, blue: 200))
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

            // The popped page hears it disappears as it leaves the tree, then the page beneath comes back.
            log.values = []
            XCTAssertTrue(host.goBack())
            XCTAssertEqual(log.values, ["Pushed disappearing", "Root appearing", "Root navigatedTo"])
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
            XCTAssertEqual(navigation.bar.content.navigation, .sidebar)

            navigation.bar.clicked()
            XCTAssertTrue(open.wrappedValue)
            XCTAssertTrue(split.isPresented)

            XCTAssertTrue(host.goBack())
            XCTAssertFalse(open.wrappedValue)
            XCTAssertFalse(split.isPresented)
        }
    }

    /// On a tablet the sidebar stands beside the detail under a bar of its own - its page's title and picture as the
    /// application's mark, and at its end the toggle hiding the sidebar in Android's own glyph; hidden, the detail's
    /// bar shows the toggle, which shows it again.
    func testTheSidebarsOwnBarHidesItAndTheDetailsShowsIt() throws {
        try onMainActor {
            let open = State(wrappedValue: true)
            let host = AndroidRenderer.running {
                SplitView(open.projectedValue) {
                    TitledPage(title: "Notes", icon: "test_wide.png")
                } detail: {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        TitledPage(title: "Home")
                    } destination: { _ in
                        TitledPage(title: "Deeper")
                    }
                }
            }
            host.layOut(width: 2000, height: 1600)
            host.runtime.pump.turn()
            let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            let sidebar = split.drawer.bar
            XCTAssertFalse(split.overlays, "beside the detail")
            XCTAssertEqual(sidebar.content.title, "Notes")
            XCTAssertEqual(sidebar.content.mark, .file("test_wide.png"))
            XCTAssertEqual(sidebar.content.endButton, .sidebar)
            XCTAssertEqual(navigation.bar.content.navigation, .none, "the toggle on the sidebar's own bar")

            sidebar.chose(Int(AndroidBarButton.atEnd.rawValue))
            XCTAssertFalse(open.wrappedValue)
            XCTAssertFalse(split.isPresented)
            XCTAssertEqual(navigation.bar.content.navigation, .sidebar, "now on the detail's")

            navigation.bar.clicked()
            XCTAssertTrue(open.wrappedValue)
            XCTAssertTrue(split.isPresented)
            XCTAssertEqual(navigation.bar.content.navigation, .none)
        }
    }

    /// A page pushed in the detail keeps the sidebar's toggle while the sidebar does not show - over the detail on a
    /// phone, hidden beside it on a tablet: the toggle first, then the way back; each does its own.
    func testAPushedPageKeepsTheSidebarsToggleBeforeTheWayBack() throws {
        try onMainActor {
            for (width, height) in [(Int32(1080), Int32(1920)), (2000, 1600)] {
                let open = State(wrappedValue: false)
                let path = State(wrappedValue: [1])
                let host = AndroidRenderer.running {
                    SplitView(open.projectedValue) {
                        TitledPage(title: "Menu", icon: "test_dot.png")
                    } detail: {
                        NavigationStack(path.projectedValue) {
                            TitledPage(title: "Home")
                        } destination: { _ in
                            TitledPage(title: "Deeper")
                        }
                    }
                }
                host.layOut(width: width, height: height)
                host.runtime.pump.turn()
                // A first room wide enough shows the sidebar; the program hides it.
                open.wrappedValue = false
                host.runtime.pump.turn()
                host.layOut(width: width, height: height)
                let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
                let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
                XCTAssertFalse(split.isPresented, "\(width)")
                XCTAssertEqual(navigation.bar.content.navigation, .sidebar, "\(width)")
                XCTAssertEqual(navigation.bar.content.afterNavigation, .back, "\(width)")

                navigation.bar.chose(Int(AndroidBarButton.afterNavigation.rawValue))
                host.runtime.pump.turn()
                XCTAssertEqual(path.wrappedValue, [], "back pops the page, \(width)")
                XCTAssertEqual(navigation.bar.content.afterNavigation, .none, "\(width)")

                navigation.bar.clicked()
                XCTAssertTrue(open.wrappedValue, "the toggle shows the sidebar, \(width)")
            }
        }
    }

    /// A split view offering its toggle at the detail's root alone - a value from the path - leaves a pushed page
    /// the way back first, and the root the toggle; the sidebar's own bar shows it as the split view says.
    func testAPushedPageShowsOnlyTheWayBackWhereTheSplitViewOffersNoToggle() throws {
        try onMainActor {
            let path = State(wrappedValue: [1])
            let host = AndroidRenderer.running {
                SplitView(State(wrappedValue: false).projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    NavigationStack(path.projectedValue) {
                        TitledPage(title: "Home")
                    } destination: { _ in
                        TitledPage(title: "Deeper")
                    }
                }
                .showsSidebarToggle(path.wrappedValue.isEmpty)
            }
            host.layOut(width: 1080, height: 1920)
            host.runtime.pump.turn()
            let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.navigation, .back, "the way back alone")
            XCTAssertEqual(navigation.bar.content.afterNavigation, .none)
            XCTAssertEqual(split.drawer.bar.content.endButton, .none, "no toggle on the sidebar's own bar")

            navigation.bar.clicked()
            host.runtime.pump.turn()
            XCTAssertEqual(path.wrappedValue, [], "back pops the page")
            XCTAssertEqual(navigation.bar.content.navigation, .sidebar, "the root offers the toggle")
            XCTAssertEqual(split.drawer.bar.content.endButton, .sidebar)
        }
    }

    /// The sidebar's bar and the detail's stand as one: at one height, their words on one line.
    func testTheSidebarsBarStandsAsHighAsTheDetails() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    TitledPage(title: "Notes", icon: "test_wide.png")
                } detail: {
                    NavigationStack(State(wrappedValue: [1]).projectedValue) {
                        TitledPage(title: "Home")
                    } destination: { _ in
                        TitledPage(title: "Deeper", actions: [ToolbarButton("Save").icon("test_wide.png")])
                    }
                }
            }
            host.insetsChanged(left: 0, top: 48, right: 0, bottom: 96, keyboard: 0)
            // Laid out until the bars hold what the first room said of the sidebar, as a window's passes do.
            for _ in 0..<3 {
                host.layOut(width: 2000, height: 1600)
                host.runtime.pump.turn()
            }
            let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertFalse(split.overlays)
            XCTAssertEqual(split.drawer.bar.frame.height, navigation.bar.frame.height, "one height")
            let beside = BarLines.middles(navigation.bar)
            XCTAssertEqual(beside.count, 3, "the way back, the title, the action: \(beside)")
            XCTAssertEqual(beside.max() ?? 0, beside.min() ?? 0, accuracy: 2, "on one line")
            XCTAssertEqual(BarLines.middles(split.drawer.bar).first ?? 0, beside.first ?? 0, accuracy: 2, "both bars")

            split.drawer.bar.chose(Int(AndroidBarButton.atEnd.rawValue))
            for _ in 0..<3 {
                host.runtime.pump.turn()
                host.layOut(width: 2000, height: 1600)
            }
            let hidden = BarLines.middles(navigation.bar)
            XCTAssertEqual(hidden.count, 4, "the toggle, the way back, the title, the action: \(hidden)")
            XCTAssertEqual(hidden.max() ?? 0, hidden.min() ?? 0, accuracy: 2, "on one line")
        }
    }

    /// Beside the detail the sidebar stands apart from it by the theme's line down its edge toward the detail; as a
    /// drawer over the detail it stands on its own edge, with no line.
    func testTheSidebarBesideTheDetailStandsApartByALine() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) { TitledPage(title: "Menu") } detail: { ZStack {} }
            }
            for _ in 0..<2 {
                host.layOut(width: 2000, height: 1600)
                host.runtime.pump.turn()
            }
            let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
            let column = split.drawer
            XCTAssertTrue(column.heldViews().contains { $0 === column.edge }, "beside the detail")
            let line = column.edge.frame
            XCTAssertGreaterThan(line.width, 0)
            XCTAssertEqual(line.x + line.width, column.frame.width, "at the edge toward the detail")
            XCTAssertEqual(line.height, column.frame.height, "down the whole edge")

            host.layOut(width: 1080, height: 1920)
            XCTAssertFalse(column.heldViews().contains { $0 === column.edge }, "a drawer over the detail")
        }
    }

    /// Beside the detail the sidebar moves as one with it - Android's own transition, in a window wide enough for
    /// the sidebar beside the detail: hiding, it slides out by its own width as the detail widens, and showing, in
    /// by it as the detail narrows; the detail's bar changes in place, nothing on it sliding.
    func testTheSidebarBesideTheDetailMovesWithIt() throws {
        try onMainActor {
            let open = State(wrappedValue: true)
            let host = AndroidRenderer.running {
                SplitView(open.projectedValue) {
                    TitledPage(title: "Menu")
                } detail: {
                    NavigationStack(State(wrappedValue: [1]).projectedValue) {
                        TitledPage(title: "Home")
                    } destination: { _ in
                        TitledPage(title: "Deeper")
                    }
                    .id("detail")
                }
            }
            Java.call(TestContext.window.reference, AndroidDriver.setContentView, .object(host.root.reference))
            TestWindow.run(for: 300)
            let window = try XCTUnwrap(Java.callObject(host.root.reference, AndroidDriver.getParent))
            let (width, height) = (Java.callInt(window, TestJava.getWidth), Java.callInt(window, TestJava.getHeight))
            Java.release(local: window)
            guard Double(width) / 2 >= AndroidSplitView.sideBySide else {
                throw XCTSkip("the window is too narrow for the sidebar beside the detail")
            }
            host.layOut(width: width, height: height)
            TestWindow.run(for: 300)
            let split = try XCTUnwrap(host.views(AndroidSplitView.self).first)
            let detail = try XCTUnwrap(host.view(id: .manual("detail")) as? AndroidNavigationView)
            let beside = detail.frame.width
            let column = Float(split.drawer.frame.width)
            XCTAssertLessThan(beside, width, "the detail beside the sidebar")

            for (shows, from, to) in [(false, beside, width), (true, width, beside)] {
                open.wrappedValue = shows
                host.runtime.pump.turn()
                host.layOut(width: width, height: height)
                TestWindow.run(for: 80)
                let moving = detail.frame.width
                let across = Java.callFloat(split.drawer.outermost, TestJava.getTranslationX)
                let shifted = BarLines.shifted(detail.bar)
                TestWindow.run(for: 500)

                XCTAssertTrue((min(from, to) + 1..<max(from, to)).contains(moving), "the detail on its way: \(moving)")
                XCTAssertTrue((-column + 1..<0).contains(across), "the sidebar moving by its own width: \(across)")
                XCTAssertEqual(shifted, 0, "nothing on the detail's bar slides")
                XCTAssertEqual(detail.frame.width, to, "where the move ends")
            }
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

            XCTAssertEqual(navigation.bar.content.navigation, .sidebar)
            let glyph = Java.frame { Java.callObject(navigation.bar.reference, TestJava.getNavigationIcon) != nil }
            XCTAssertTrue(glyph, "the bar shows a button to open the sidebar")
        }
    }

    /// A drawer over the detail stands on a surface of its own - the theme's floating one - never on the window's: a
    /// window painted clear leaves the drawer opaque, the detail hidden behind a sidebar page that paints nothing.
    func testADrawerUnderAClearWindowStandsOnASurfaceOfItsOwn() throws {
        try onMainActor {
            stateUIUseApp(OneWindowApplication {
                WindowPainted(color: .transparent) {
                    drawerOverStack(sidebar: TitledPage(title: "Menu", icon: "test_dot.png"))
                }
            })
            // In the activity's window, which the window's color paints; its theme's back comes back after.
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

            let color = Java.callStaticLong(JavaAPI.views, AndroidDriver.sidebarColor, .object(drawer.reference))
            XCTAssertNotEqual(color, Int64.min, "the drawer stands on a surface")
            XCTAssertEqual(UInt32(truncatingIfNeeded: color) >> 24, 0xFF, "an opaque one, whatever the window is")
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
                TabView([0, 1], selection: tab.projectedValue) { number in
                    TitledPage(title: "Tab \(number)")
                }
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
                TabView([0, 1, 2], selection: tab.projectedValue) { number in TitledPage(title: "Tab \(number)") }
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

    /// What a page puts on the bar: its actions in their order, each standing alone a group of its own and the
    /// overflow's last, each with its picture and whether it can be chosen - the picture of one that cannot be
    /// dimmed - a destructive one in the theme's error color; choosing one runs its handler, and one that cannot be
    /// chosen runs nothing.
    func testAPagesToolbarItemsAreTheBarsActions() throws {
        try onMainActor {
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Notes", actions: [
                        ToolbarButton("Delete").placement(at: .overflow).role(.destructive)
                            .onClicked { heard.values.append("delete") },
                        ToolbarButton("Add").icon("test_wide.png").isEnabled(false)
                            .onClicked { heard.values.append("add") },
                        ToolbarButton("Save").icon("test_wide.png").onClicked { heard.values.append("save") },
                    ])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
            }
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.actions.map(\.onBar), [true, true, false])

            let menu = JavaObject(try XCTUnwrap(Java.callObject(navigation.bar.reference, TestMenus.getMenu)))
            XCTAssertEqual(TestMenus.describe(menu), "Add (off) (dimmed picture) | Save (picture) | Delete (red)")
            for words in ["Add", "Save", "Delete"] { TestMenus.choose(menu, words) }
            host.runtime.pump.turn()
            XCTAssertEqual(heard.values, ["save", "delete"])
        }
    }
}

extension AndroidPagesTests {
    /// A bar with no leading edge beside its navigation button: a leading group stands first among the actions, the
    /// trailing ones after it.
    func testALeadingGroupStandsFirstAmongTheActions() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Notes", actions: [ToolbarButton("Save"), ToolbarButton("Filter").placement(at: .start)])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
            }
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(navigation.bar.content.actions.map(\.text), ["Filter", "Save"])
        }
    }

    /// The actions standing on a painted bar take their words from the bar's theme - light on a dark bar, dark on a
    /// light one - as Android's own bars do; their pictures take the bar's words' color itself. A bar painted
    /// again in the other shade is made again in its theme.
    func testTheBarsActionsStandInItsWordsColor() throws {
        try onMainActor {
            let dark = State(wrappedValue: true)
            let host = AndroidRenderer.running(reducesMotion: true) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    TitledPage(title: "Notes", actions: [
                        ToolbarButton("Scan"),
                        ToolbarButton("Save").icon("test_wide.png"),
                    ])
                } destination: { _ in
                    TitledPage(title: "Note")
                }
                .barBackground(dark.wrappedValue ? .purple : .yellow)
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

    /// The stack colors its bar; a page says whether the bar shows and whether it has a way back, and what
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
                .barBackground(.red)
                .barForegroundColor(.white)
            }
            host.layOut()
            let navigation = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            XCTAssertEqual(Self.color(of: navigation.bar), 0xFFFF_0000)
            XCTAssertEqual(navigation.bar.content.foreground.flatMap(AndroidView.argb), Int32(bitPattern: 0xFFFF_FFFF))
            let page = try XCTUnwrap(host.views(AndroidSingleChildView.self).first)
            XCTAssertEqual(Self.color(of: page), 0xFF00_00FF)
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
                            actions: [ToolbarButton("Dot").icon("test_dot.png"), ToolbarButton("Wide").icon("test_wide.png")])
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

    /// The color a view's background is painted in.
    @MainActor
    private static func color(of view: AndroidView) -> UInt32 {
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

    /// A page a view presents as a sheet stands over the window's page; back takes it down, its state hears it,
    /// and the page under it shows again.
    func testASheetPresentsOverThePageAndBackTakesItDown() {
        onMainActor {
            let (first, second) = (State(wrappedValue: false), State(wrappedValue: false))
            let log = Received<String>()
            let host = AndroidRenderer.running(reducesMotion: true) { sheetsPage(first, second, log: log) }
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 1)

            log.values = []
            first.wrappedValue = true
            host.runtime.pump.turn()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 2, "the page, and the sheet over it")
            XCTAssertEqual(
                log.values.filter { $0.hasSuffix("appearing") }, ["Page disappearing", "Sheet 1 appearing"])

            log.values = []
            XCTAssertTrue(host.goBack())
            XCTAssertFalse(first.wrappedValue)
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 1)
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Sheet 1 disappearing", "Page appearing"])
        }
    }

    /// A sheet fills a window narrower than 600 points; in a wider one it stands on a card as large as its page asks
    /// - here the least, its words few - and one holding a stack, whose pages come and go, at the standard size, two
    /// pixels a point.
    func testASheetStandsOnACardAsLargeAsItsPageInAWideWindow() throws {
        try onMainActor {
            let host = AndroidRenderer.running(reducesMotion: true) {
                VStack {
                    Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) { Text("A note") }
                    Text("Under").sheet(isPresented: State(wrappedValue: true).projectedValue) {
                        NavigationStack(State(wrappedValue: [Int]()).projectedValue) { Text("Root") } destination: { _ in
                            Text("Next")
                        }
                    }
                }
            }
            host.runtime.pump.turn()
            let window = try XCTUnwrap(host.runtime.tree.root?.first(type: .window))
            let sheets = host.runtime.tree.presentedSheets(in: window)
            XCTAssertEqual(sheets.count, 2)
            let (note, stack) = (sheets[0], sheets[1])
            @MainActor func card(_ sheet: MountedElement, _ width: Double) -> [Int32] {
                let card = AndroidModals.card(for: sheet, in: LayoutSize(width: width, height: 800))
                return [card.width, card.height]
            }

            XCTAssertEqual(card(note, 599), [0, 0], "filling a narrow window")
            XCTAssertEqual(card(note, 1000), [560, 360], "its least")
            XCTAssertEqual(card(stack, 1000), [1120, 1280], "the standard size")

            let page = TestJava.root()
            let holder = try withExtendedLifetime(page) {
                try XCTUnwrap(Java.callStaticObject(
                    JavaAPI.views, JavaAPI.sheet, .object(AndroidRenderer.context), .object(page.reference),
                    .int(600), .int(400)).map(JavaObject.init))
            }
            Java.call(holder.reference, JavaAPI.measure, .int(ViewConstants.spec(ViewConstants.exactly, 2000)),
                      .int(ViewConstants.spec(ViewConstants.exactly, 1600)))
            Java.call(holder.reference, JavaAPI.layout, .int(0), .int(0), .int(2000), .int(1600))
            let shown = try XCTUnwrap(Java.callObject(holder.reference, TestJava.getChildAt, .int(0)).map(JavaObject.init))
            XCTAssertEqual([Java.callInt(shown.reference, TestJava.getWidth), Java.callInt(shown.reference, TestJava.getHeight)],
                           [600, 400], "a card in the middle")
        }
    }

    /// The activity's root drawn edge to edge, as an application's is, hears what stands over it in its window: the
    /// status bar at the top.
    func testARootDrawnEdgeToEdgeHearsTheStatusBar() {
        onMainActor {
            let host = AndroidRenderer.running(reducesMotion: true) { ZStack {} }
            let (window, root) = (TestContext.window.reference, host.root.reference)
            Java.call(window, AndroidDriver.setContentView, .object(root))
            Java.callStatic(JavaAPI.views, Self.edgeToEdge, .object(window), .object(root), .bool(true))
            defer { Java.callStatic(Self.systemBars, Self.fitted, .object(window), .object(root)) }
            TestWindow.run(for: 300)
            XCTAssertGreaterThan(host.windowInsets.top, 0, "the status bar")
        }
    }

    @MainActor private static let edgeToEdge = Java.staticMethod(
        JavaAPI.views, "edgeToEdge", "(Landroid/app/Activity;Landroid/view/View;Z)V")
    @MainActor private static let systemBars = Java.findClass("stateui/android/test/TestSystemBars")
    @MainActor private static let fitted = Java.staticMethod(
        systemBars, "fitted", "(Landroid/app/Activity;Landroid/view/View;)V")

    /// Drawn edge to edge, a page's content stands clear of what stands over the window - the status bar, the
    /// navigation bar - and where it lets itself under the bars it reaches the window's edges; two pixels a point.
    func testAPageStandsClearOfTheSystemsBarsUnlessItSaysSo() throws {
        try onMainActor {
            let under = State(wrappedValue: false)
            let host = AndroidRenderer.running(reducesMotion: true) {
                ZStack {}.ignoresSafeArea(under.wrappedValue ? .all : .none).id("content")
            }
            host.insetsChanged(left: 0, top: 48, right: 0, bottom: 96, keyboard: 0)
            host.layOut()
            let content = try XCTUnwrap(host.view(id: .manual("content")))
            XCTAssertEqual([content.frame.y, content.frame.height], [48, 1920 - 48 - 96], "clear of both bars")

            under.wrappedValue = true
            host.runtime.pump.turn()
            host.layOut()
            XCTAssertEqual([content.frame.y, content.frame.height], [0, 1920], "under them")
        }
    }

    /// A stack's bar reaches under the status bar, its own words clear of it, and its page stands below it, clear of
    /// the navigation bar.
    func testAStacksBarReachesUnderTheStatusBar() throws {
        try onMainActor {
            let host = AndroidRenderer.running(reducesMotion: true) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    ZStack {}.id("content").title("Under the bar")
                } destination: { _ in Text("Next") }
            }
            host.insetsChanged(left: 0, top: 48, right: 0, bottom: 96, keyboard: 0)
            host.layOut()
            let stack = try XCTUnwrap(host.views(AndroidNavigationView.self).first)
            let bar = stack.bar
            XCTAssertEqual(bar.frame.y, 0, "from the screen's top")
            XCTAssertEqual(Java.callInt(bar.reference, TestJava.getPaddingTop), 48, "its words clear of the status bar")
            let content = try XCTUnwrap(host.view(id: .manual("content")))
            XCTAssertEqual(content.frame.y, 0, "the page right below the bar, in its own place")
            XCTAssertEqual(content.frame.height, 1920 - bar.frame.height - 96, "clear of the navigation bar")
        }
    }

    /// A page's scroller let under the navigation bar keeps its depth clear at its end, Android's padding drawn
    /// through, so its last row scrolls out from under it.
    func testAPagesScrollerUnderTheNavigationBarKeepsItsLastRowClear() throws {
        try onMainActor {
            let host = AndroidRenderer.running(reducesMotion: true) {
                Grid { ScrollView { Text("rows").height(2000) } }.ignoresSafeArea(.all)
            }
            host.insetsChanged(left: 0, top: 48, right: 0, bottom: 96, keyboard: 0)
            host.layOut()
            let scroll = try XCTUnwrap(host.views(AndroidScrollView.self).first?.scrollers.first)
            XCTAssertEqual(Java.callInt(scroll.reference, TestJava.getPaddingTop), 48)
            XCTAssertEqual(Java.callInt(scroll.reference, TestJava.getPaddingBottom), 96)
        }
    }

    /// The program closing sheets takes their pages down after the tree has let them go - a page shown hears it
    /// disappears as it leaves, and nothing more - and the page under them shows again.
    func testThePageUnderPagesTheProgramTakesDownShowsAgain() {
        onMainActor {
            let (first, second) = (State(wrappedValue: false), State(wrappedValue: false))
            let log = Received<String>()
            let host = AndroidRenderer.running(reducesMotion: true) { sheetsPage(first, second, log: log) }
            (first.wrappedValue, second.wrappedValue) = (true, true)
            host.runtime.pump.turn()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 3)

            log.values = []
            second.wrappedValue = false
            host.runtime.pump.turn()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 2)
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Sheet 2 disappearing", "Sheet 1 appearing"])

            log.values = []
            first.wrappedValue = false
            host.runtime.pump.turn()
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 1)
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Sheet 1 disappearing", "Page appearing"])
        }
    }

    /// A window showing another arrangement: the one the tree let go hears it disappears as it goes, then the new one
    /// appears.
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
            XCTAssertEqual(log.values.filter { $0.hasSuffix("appearing") }, ["Page disappearing", "Root appearing"])
        }
    }

    /// The inspector docked in the window is its overlay: over the page and over a page presented after it,
    /// taking no touch beside its panel, and gone once the inspector closes.
    func testTheWindowsOverlayStandsOverItsPagesAndLetsATouchBesideItThrough() throws {
        try onMainActor {
            let (first, second) = (State(wrappedValue: false), State(wrappedValue: false))
            let windows = Received<WindowSession>()
            let host = AndroidRenderer.running(reducesMotion: true) { sheetsPage(first, second, windows: windows) }
            let session = try XCTUnwrap(windows.values.last)
            defer { session.closeInspector() }
            host.layOut()

            session.openInspector()
            host.runtime.pump.turn()
            host.layOut()
            let overlay = try XCTUnwrap((host.runtime.tree.root?.first(type: .overlay)?.native as? AndroidElement)?.view, "no overlay view")
            let root = host.root.reference
            XCTAssertEqual(Java.callInt(root, TestJava.getChildCount), 2, "the page, and the overlay over it")
            XCTAssertEqual(Java.callInt(root, TestJava.indexOfChild, .object(overlay.reference)), 1)
            XCTAssertEqual(overlay.frame.width, 1080)
            XCTAssertEqual(overlay.frame.height, 1920)
            XCTAssertFalse(overlay.touched(x: 540, y: 100), "the overlay took a touch beside its panel")

            first.wrappedValue = true
            host.runtime.pump.turn()
            XCTAssertEqual(Java.callInt(root, TestJava.getChildCount), 3)
            XCTAssertEqual(Java.callInt(root, TestJava.indexOfChild, .object(overlay.reference)), 2, "under the sheet")

            session.closeInspector()
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

/// A page telling its window, presenting a sheet while `first` which presents another in it while `second`.
@MainActor
private func sheetsPage(
    _ first: State<Bool>, _ second: State<Bool>, log: Received<String> = Received(),
    windows: Received<WindowSession> = Received()
) -> some View {
    ScenePage(log: log, windows: windows)
        .sheet(isPresented: first.projectedValue) {
            TitledPage(title: "Sheet 1", log: log)
                .sheet(isPresented: second.projectedValue) { TitledPage(title: "Sheet 2", log: log) }
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

/// `content` in a window painted `color`.
private struct WindowPainted<Content: View>: View {
    @Environment(\.window) private var window
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        let (window, color) = (self.window, self.color)
        return content().onCreated { window.background = .color(color) }
    }
}

/// A page that names itself, and writes each phase it hears into `log`.
private struct TitledPage: View {
    let title: String
    var icon: ImageSource? = nil
    var log: Received<String>? = nil
    var actions: [ToolbarButton] = []

    var body: some View {
        let words = Text(title).toolbar { actions }.title(title)
        return (icon.map { words.icon($0) } ?? words).loggingPhases(log, as: title)
    }
}

/// Where the bar's buttons and words stand: `TestBars.java`.
@MainActor
private enum BarLines {
    private static let shiftedViews = Java.staticMethod(
        Java.findClass("stateui/android/test/TestBars"), "shifted", "(Landroid/view/View;)I")

    /// How many views `bar` holds stand shifted across, as a slide moves them.
    static func shifted(_ bar: AndroidView) -> Int {
        Int(Java.callStaticInt(Java.findClass("stateui/android/test/TestBars"), shiftedViews, .object(bar.reference)))
    }

    private static let owner = Java.findClass("stateui/android/test/TestBars")
    private static let read = Java.staticMethod(owner, "middles", "(Landroid/widget/Toolbar;)Ljava/lang/String;")

    /// The vertical middle, in pixels from the bar's top, of each button and line of words it shows - the bar laid
    /// out again at its size first, as a window lays out a toolbar that asked for it.
    static func middles(_ bar: AndroidView) -> [Double] {
        bar.layOut(width: bar.frame.width, height: bar.frame.height)
        let said = Java.frame {
            Java.callStaticObject(owner, read, .object(bar.reference)).map { Java.text($0) } ?? ""
        }
        return said.split(separator: ",").compactMap { Double($0) }
    }
}

/// The color a page's view stands on, as ARGB.
@MainActor
private enum PageGround {
    private static let colorDrawable = Java.findClass("android/graphics/drawable/ColorDrawable")
    private static let getColor = Java.method(colorDrawable, "getColor", "()I")

    /// The color `page`'s view is painted in; nil where it paints none, or no one color.
    static func color(of page: MountedElement) -> UInt32? {
        guard let view = (page.native as? AndroidElement)?.view,
              let ground = Java.callObject(view.reference, JavaAPI.getBackground)
        else { return nil }
        defer { Java.release(local: ground) }
        guard Java.jni.IsInstanceOf(Java.env, ground, colorDrawable) != 0 else { return nil }
        return UInt32(truncatingIfNeeded: Java.callInt(ground, getColor))
    }
}
