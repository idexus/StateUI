// Where a gallery is, and every move it can make.
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
    /// `TabbedPage` rather than as a stack. See `MainWindow.detail`.
    case tabs
}

/// A page pushed on TOP of a section, with a back button over it.
///
/// The parameters ride as associated values, which is the whole difference from
/// a route string: a dictionary of parameters is checked by nobody, and this is
/// a compiler-checked enum whose `destination` closure must answer every case.
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
/// has to keep in step. See `MainWindow.tabs`, which is the one place in the
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

/// Where one gallery is, and the moves that change it.
///
/// A CLASS OF `@State` PROPERTIES, held by the gallery's scene and offered to
/// every window of it. Each property has its own readers: a page that reads
/// `nav.path` is built again when the path moves and a menu row that reads
/// `nav.section` when the section does - and `nav.$path` is the state itself,
/// handed to the `NavigationPage` that shows it. A second gallery holds a
/// `Navigation` of its own.
///
/// Every move is a plain assignment. There is no `await` anywhere in this file,
/// because navigation is state this side owns, not a request to MAUI whose
/// answer arrives later - so no handler has to be `async` on its account, and
/// the next render is what moves the screen.
final class Navigation {
    /// Which section the menu has chosen.
    @State var section: Section = .home

    /// What is pushed on top of it, deepest last. A platform back gesture
    /// truncates this by itself: the host reports the depth that SURVIVED and
    /// `NavigationPage` writes it back through `$path`, so this array is never
    /// a stale copy of where the reader is.
    @State var path: [Route] = []

    /// Whether the menu is showing - two-way: a swipe that closes it writes
    /// `false` back.
    @State var menuOpen = false

    /// Whether the edge swipe may open the menu. The buttons work either way.
    @State var menuGesture = true

    /// Whether the menu lists the row that is hidden by default - see
    /// `FlyoutSample`, which is where the switch that writes it lives.
    @State var listsHiddenRow = false

    /// What is presented over all of it, innermost first. Usually empty, and
    /// almost always one deep when it is not - it is a stack because the
    /// platforms make it one: a sheet may present a sheet.
    @State var sheets: [Sheet] = []

    /// The tabs the demonstration is showing, in order - the LIST a
    /// `TabbedPage` is built over, held as state so that the reader can change
    /// it while a tab is selected. See `TabsControls`.
    @State var tabs: [DemoTab] = DemoTab.opening

    /// Which of them is showing. The tabs write it when the reader taps one,
    /// and the gallery writes it to move them from code - the same state both
    /// ways, which is what `TabbedPage.selection` is.
    @State var tab: DemoTab = .stack

    /// What the stack tab has pushed - its own array, which is what makes each
    /// tab keep its place: the stacks are separate because the ARRAYS are
    /// separate, with nothing in the library deciding it.
    @State var tabsPath: [Route] = []

    /// What the last change to the tab list put on the wire, in one line, for
    /// `TabsControls` to print. Written by the moves below and by nothing else.
    @State var tabsNote = "nothing has changed the tabs yet"

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

extension Navigation {
    /// Opens a sample nobody asked for - the menu's last row and the title
    /// bar's chip both call it. Flattened, so every sample is as likely as
    /// every other - picking a group first would favour whatever is in the
    /// shortest one - and drawn from what `idiom` shows, so a phone is never
    /// surprised with a page about desktop chrome.
    ///
    /// A method on values both callers already hold: a closure handed down
    /// would be an input nothing can compare, and every view holding one would
    /// be built again with its parent.
    ///
    /// Two assignments: the menu closes and the page goes on the stack, and
    /// the next render is what moves the screen.
    func surprise(from catalog: Catalog, on idiom: DeviceIdiom) {
        guard let sample = catalog.groups
            .flatMap({ $0.shown(on: idiom) })
            .randomElement()
        else { return }

        menuOpen = false
        push(.sample(sample.id))
    }
}
