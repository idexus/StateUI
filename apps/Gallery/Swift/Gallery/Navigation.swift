// Where the gallery is, and every move it can make.
//
// This file is the gallery's whole navigation model, and there is nothing in the
// library like it - deliberately. A `NavigationPage` takes an ARRAY the author
// holds; a `FlyoutPage` takes a `Bool`; a `TabbedPage` takes a value of the
// author's own type. What is in those, what the moves are called and what a move
// means are this application's business, so they are written here.
//
// Which is the answer to "where is the router?": an application that wants one
// writes it, in about forty lines, with its own names. The library ships
// containers and bindings and no router at all - a second one under a library
// name would be the second way to do something, which this library refuses.

import StateUI

/// A place the menu can choose: one row, one page under it.
///
/// A VALUE, and it has to be one - the detail page is rebuilt from it on every
/// render, and a menu row asks `nav.showing(.home)` to know whether it is the
/// row the reader is on - a question this application answers, because this
/// application is what holds the section.
enum Section: Hashable {
    /// What the gallery opens with, and the ROOT of the main stack - a group is
    /// pushed on top of it rather than replacing it, because that is what the
    /// chevron on a home card promises and what a back button then honours.
    case home

    /// The page the menu lists only when it is told to - see `FlyoutSample`.
    case hidden

    /// The tabs demonstration, which is the one section arranged as a
    /// `TabbedPage` rather than as a stack. See `GalleryApp.detail`.
    case tabs
}

/// A page pushed on TOP of a section, with a back button over it.
///
/// The parameters ride as associated values, which is the whole difference from
/// a route string: `["id": sample.id]` was a dictionary nobody could check, and
/// this is a compiler-checked enum whose `destination` closure must answer every
/// case.
enum Route: Hashable {
    /// One group of samples, by the route in `Catalog` - `.group("layout")`.
    ///
    /// A ROUTE rather than a section: the home page lists the groups with a
    /// chevron on every row, so choosing one PUSHES it and the platform's back
    /// button leads home. An associated value rather than one case per group,
    /// because adding a group is a line in the catalog and must not be a change
    /// here.
    case group(String)

    /// One sample's page, by the id it is filed under in `Catalog`.
    case sample(String)

    /// One step of the drill-down - see `LevelPage`.
    case level(Int)

    /// A thing chosen from the search box - see `SearchSample`.
    case item(String)
}

/// One tab of the tabs demonstration.
///
/// The tabs are a collection of the AUTHOR's type and the selection is a binding
/// of it - so what shows is `tab == .second`, not an index into a list somebody
/// has to keep in step. See `GalleryApp.detail`, which is the one place in the
/// gallery where the detail page is not a stack.
enum DemoTab: Hashable {
    /// The tab holding a navigation stack of its own.
    case stack

    /// The plain one beside it, which is what shows that a tab keeps its place.
    case second

    /// One the reader added, by number. What makes the LIST something that
    /// changes rather than a fixed set - see `TabsControls`.
    case extra(Int)

    /// The two the tabs open with, and what `Reset` puts back.
    static let opening: [DemoTab] = [.stack, .second]

    /// What the tab is called.
    ///
    /// The same words the tab's page gives its `title`, so the list this
    /// demonstration prints and the platform's own tab strip can be read against
    /// each other - which is the whole of the measurement.
    var caption: String {
        switch self {
        case .stack: return "Stack"
        case .second: return "Second"
        case .extra(let number): return "Extra \(number)"
        }
    }
}

/// A page the gallery presents OVER everything - see `ModalSample`.
///
/// The modal stack is the WINDOW's, so this is the one place in the gallery
/// where a value names something that covers the bars as well as the content.
enum Sheet: Hashable {
    /// The platform's own modal page, drawn in the style named - which is a
    /// choice on iOS and Mac Catalyst, and full screen everywhere else.
    case page(UIModalPresentationStyle)

    /// The sheet the GALLERY draws and animates: a transparent modal page with
    /// a card slid up from the bottom of it, which looks the same on all four
    /// platforms because nothing about it is the platform's.
    case card
}

/// The gallery's navigation, lent to whoever can move.
///
/// Three bindings and the moves that write them. It is a STRUCT of bindings
/// rather than a model class because it owns nothing: the state lives on
/// `GalleryApp`, as `@State`, and this is the borrowing end of it - so a page
/// given one can move the application without being able to keep a stale copy
/// of where it is.
///
/// Every move is a plain assignment. There is no `await` anywhere in this file,
/// because navigation is state this side owns, not a request to MAUI whose
/// answer arrives later - so no handler has to be `async` on its account, and
/// the next render is what moves the screen.
struct Navigation {
    /// Which section the menu has chosen.
    @Binding var section: Section

    /// What is pushed on top of it, deepest last.
    @Binding var path: [Route]

    /// Whether the menu is showing.
    @Binding var menuOpen: Bool

    /// Whether the edge swipe may open the menu. The buttons work either way.
    @Binding var menuGesture: Bool

    /// What is presented over all of it, innermost first. Usually empty, and
    /// almost always one deep when it is not - it is a stack because the
    /// platforms make it one: a sheet may present a sheet.
    @Binding var sheets: [Sheet]

    /// The inspector WINDOWS that are open, by number - see
    /// `MultiWindowSample`. A window is not part of where the reader IS, which
    /// is why this is a list of its own rather than another section: all of
    /// them are showing at once.
    @Binding var inspectors: [Int]

    /// The DOCUMENT windows that are open, by number - the ones the PLATFORM
    /// was asked for rather than the interface: *File ▸ New Window* on a Mac,
    /// the window controls on an iPad. A list of their own beside the
    /// inspectors, because they are opened by a different gesture and say a
    /// different thing; to the library they are the same thing, which is one
    /// more entry in `windows`.
    @Binding var documents: [Int]

    /// The tabs the demonstration is showing, in order - the LIST a
    /// `TabbedPage` is built over, held as state so that the reader can change
    /// it while a tab is selected. See `TabsControls`.
    @Binding var tabs: [DemoTab]

    /// Which of them is showing. The tabs write it when the reader taps one,
    /// and the gallery writes it to move them from code - the same binding both
    /// ways, which is what `TabbedPage.selection` is.
    @Binding var tab: DemoTab

    /// What the last change to the tab list put on the wire, in one line, for
    /// `TabsControls` to print. Written by the moves below and by nothing else.
    @Binding var tabsNote: String

    /// Goes to a section, from the top, with the menu closed behind it.
    ///
    /// The path is emptied on purpose: choosing a section from the menu starts
    /// it again, so "go home" is one move and lands where the reader expects.
    /// An app that would rather each section KEPT its stack holds one array per
    /// section instead - the tabs do exactly that, in `tabsPath`.
    func open(_ wanted: Section) {
        section = wanted
        path = []
        menuOpen = false
    }

    /// Goes to a group of samples, ON TOP OF HOME.
    ///
    /// The whole difference from `open`: home is the root of the main stack, so
    /// a group is a page pushed onto it and the back button leads home from
    /// anywhere. Chosen from the MENU it is still one move - the path is
    /// replaced rather than appended, so picking a second group from inside the
    /// first does not stack them - and chosen from a home card it is an ordinary
    /// `push`, which is what the row's chevron says it will be.
    func openGroup(_ route: String) {
        section = .home
        path = [.group(route)]
        menuOpen = false
    }

    /// Pushes a page on top of whatever is showing.
    ///
    /// There is deliberately no `back()` beside it. A page that offers a way
    /// back takes the ARRAY IT IS ON as a binding and shortens that - see
    /// `LevelPage` - because the gallery has two stacks, the main one and the
    /// one inside a tab, and "back" means the one the page is a member of. The
    /// platform's own back button needs none of this: the host reports the depth
    /// that survived and `NavigationPage` truncates the right array itself.
    func push(_ route: Route) {
        path.append(route)
    }

    /// Back to the beginning: the home page with nothing on top of it.
    func home() {
        open(.home)
    }

    /// Whether a section is the one showing - what draws a menu row as chosen.
    ///
    /// Home answers this only when nothing is pushed over it: with a group on
    /// the stack the reader is IN that group, and the menu says so on the
    /// group's own row.
    func showing(_ wanted: Section) -> Bool {
        wanted == .home ? section == .home && path.isEmpty : section == wanted
    }

    /// Whether a group is the one showing - the same question for the rows that
    /// are routes rather than sections.
    func showingGroup(_ route: String) -> Bool {
        section == .home && path.first == .group(route)
    }

    /// Presents a page over everything - the bars included, which is the whole
    /// difference from `push`.
    func present(_ sheet: Sheet) {
        sheets.append(sheet)
    }

    /// Closes the top one. A sheet the READER dismisses needs none of this: the
    /// host reports what survived and the array is truncated for us, the same
    /// way a back gesture shortens a path.
    func dismiss() {
        if !sheets.isEmpty {
            sheets.removeLast()
        }
    }

    /// Opens another window, numbered after the highest one open.
    ///
    /// Numbered rather than counted: the number IS the window's identity - it
    /// goes on the window as `.id(number)` - so reusing one that is still open
    /// would be two windows claiming to be the same.
    func openInspector() {
        inspectors.append((inspectors.max() ?? 0) + 1)
    }

    /// Closes one, by number.
    ///
    /// A removal BY VALUE, which is what makes it right from both ends: this is
    /// also the handler a window's `destroying` runs, and by then the window may
    /// already be gone.
    func closeInspector(_ number: Int) {
        inspectors.removeAll { $0 == number }
    }

    /// Answers the platform's request for a window with a new DOCUMENT.
    ///
    /// The same two lines as `openInspector`, from the other direction: there
    /// the interface asked, here the reader asked their system. The application
    /// cannot tell the difference and does not need to - both are an append to
    /// a list `windows` is built from, and the render is what opens the window.
    func openDocument() {
        documents.append((documents.max() ?? 0) + 1)
    }

    /// Closes one, by number - the handler on the document window's own
    /// `destroying`, and what its Close button runs.
    func closeDocument(_ number: Int) {
        documents.removeAll { $0 == number }
    }

    /// Closes EVERY window but the main one, whoever opened it.
    ///
    /// Two assignments, because closing N windows is describing none of them:
    /// the render that follows asks the platform to close each, which is also
    /// what destroys the scene behind it. Worth having beyond the demonstration
    /// - a Mac remembers the scenes of an app that ended with many windows open
    /// and restores them ALL at the next launch, and closing them through the
    /// tree is what takes them off that list.
    func closeExtraWindows() {
        inspectors = []
        documents = []
    }

    /// Whether there is anything for that to close.
    var hasExtraWindows: Bool {
        !inspectors.isEmpty || !documents.isEmpty
    }

    // MARK: - The tab list, which the reader changes

    /// Adds a tab at the END, numbered past whatever is already there.
    ///
    /// The selected tab keeps its index, so `TabbedPage.selection` writes the
    /// same number as last render and the differ sends NO selection at all -
    /// which is the case a tab list has to survive.
    func addTab(showing: DemoTab) {
        let was = tabs
        tabs.append(.extra(nextTabNumber()))
        noteTabMove("add at the end", was: was, showing: showing)
    }

    /// Adds one BEFORE the tab given, which moves everything after it along.
    func insertTab(before: DemoTab, showing: DemoTab) {
        let was = tabs

        guard let at = tabs.firstIndex(of: before) else { return }

        tabs.insert(.extra(nextTabNumber()), at: at)
        noteTabMove("insert before \(before.caption)", was: was, showing: showing)
    }

    /// Takes a tab out - the one being looked at, or another one.
    ///
    /// The last tab stays: a tab bar with nothing in it draws no page, so there
    /// would be nothing left to press.
    func closeTab(_ which: DemoTab, showing: DemoTab) {
        let was = tabs

        guard tabs.count > 1 else { return }

        tabs.removeAll { $0 == which }
        noteTabMove("close \(which.caption)", was: was, showing: showing)
    }

    /// Turns the list end for end, which is the move that leaves a MIDDLE tab
    /// where it was - the one case in which the arrangement changes and the
    /// selection index does not.
    func reverseTabs(showing: DemoTab) {
        let was = tabs
        tabs.reverse()
        noteTabMove("reverse", was: was, showing: showing)
    }

    /// Puts the two opening tabs back, showing the first.
    func resetTabs() {
        let was = tabs
        tabs = DemoTab.opening
        tab = .stack
        noteTabMove("reset", was: was, showing: .stack)
    }

    /// The next free number for an added tab.
    private func nextTabNumber() -> Int {
        let used = tabs.compactMap { tab -> Int? in
            if case .extra(let number) = tab { return number }
            return nil
        }

        return (used.max() ?? 0) + 1
    }

    /// Writes the one line `TabsControls` prints, working out what the move put
    /// on the wire the same way `TabbedPage.selection` does.
    private func noteTabMove(_ what: String, was: [DemoTab], showing: DemoTab) {
        let before = was.firstIndex(of: showing)
        let after = tabs.firstIndex(of: showing)

        let sent: String
        switch (before, after) {
        case (_, nil):
            sent = "currentPage: not sent - the selection names no tab"
        case (let from?, let to?) where from == to:
            sent = "index \(from) → \(to) · currentPage: NOT SENT"
        case (let from?, let to?):
            sent = "index \(from) → \(to) · currentPage: \(to)"
        default:
            sent = "currentPage: \(after ?? 0)"
        }

        tabsNote = "\(what) · \(sent)"
    }
}
