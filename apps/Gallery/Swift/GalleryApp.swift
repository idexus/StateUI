// The gallery's user interface, written in Swift.
//
// Everything in this directory is compiled into a SEPARATE Swift module from the
// StateUI library - named after the project, so here it is
// "GalleryUI". The dependency runs one way: this module imports
// StateUI, never the reverse. That is what allows the library to be published
// on its own, and what lets a second app exist alongside this one without either
// knowing about the other.
//
// HOW THIS IS LAID OUT:
//
//     GalleryApp.swift   the application - its state, its windows, and the one
//                        function this module exports
//     Gallery/           the gallery itself: its window and the arrangement in
//                        it (MainWindow.swift), where it is (Navigation.swift),
//                        what a sample is, the catalog of them, and the pages
//                        that show them
//     Styles/            what the app looks like: its palette and its styles
//     Samples/           one file per sample, in the group it belongs to
//
// ADDING A SAMPLE: write it under Samples/<Group>/ and name it in
// Gallery/Catalog.swift. Nothing else changes - the menu, the home page and the
// route that opens it are all built from that list.
//
// Nothing lists these files: every build - Apple, Android, Windows - discovers
// them by globbing this directory, subdirectories and all.

import StateUI

/// The gallery. MAUI: Application.
///
/// `windows` is read again on every render, so simply reading state in the
/// windows and their pages keeps the interface current - there is nothing to
/// invalidate by hand.
///
/// **What lives here is WHERE THE APPLICATION IS** - the very thing MAUI's
/// Shell keeps to itself. The section
/// showing, what is pushed on top of it, whether the menu is open, which tab is
/// chosen - all of it is `@State` this side owns, diffed and sent like any other
/// state, and the host reconciles the native containers to it. Nothing is a
/// route string, nothing is asked of MAUI and nothing has to be awaited: a move
/// is an assignment. See Gallery/Navigation.swift for the types and the moves.
///
/// Each sample owns its own `@State`, declared on the sample itself - and since
/// the catalog the pages hold carries the samples, that state survives for as
/// long as the catalog does, pushes and pops included.
struct GalleryApp: Application {
    /// Which kind of device this is, from the standard environment - answered
    /// by the host before the first render, so the styles below already know
    /// whether the SearchBar wants a phone's touch floor. An APPLICATION's
    /// unfilled slot answers the standard provider directly, which is what lets
    /// the window list read it outside any walk.
    @Environment var device: DeviceInfo

    /// Which section the menu has chosen.
    @State private var section: Section = .home

    /// What is pushed above it. A platform back gesture truncates this by
    /// itself: the host reports the depth that SURVIVED and `NavigationPage`
    /// writes it back through the binding, so this array is never a stale copy
    /// of where the reader is.
    @State private var path: [Route] = []

    /// Whether the menu is showing - two-way, like every binding here: a swipe
    /// that closes it writes `false` back.
    @State private var menuOpen = false

    /// What is presented OVER all of it - the modal stack, which belongs to the
    /// window rather than to any page on it. Empty almost always; see
    /// `ModalSample`, and `Sheet` in Gallery/Navigation.swift.
    @State private var sheets: [Sheet] = []

    /// The inspector WINDOWS that are open, by number - see
    /// `MultiWindowSample`. Empty on a phone, where the platform has nowhere to
    /// put a second window; opening one is `append`, and a window the reader
    /// closes takes its number out through the window's own `destroying`.
    @State private var inspectors: [Int] = []

    /// The DOCUMENT windows that are open, by number - the ones the PLATFORM
    /// asked for. Written by `onCreatingWindow` below and by nothing else in
    /// the gallery: there is no button here that opens one, because the gesture
    /// that does belongs to the system.
    @State private var documents: [Int] = []

    /// Whether the menu lists the row that is hidden by default. The
    /// APPLICATION's, like the rest of this, and lent to the sample that toggles
    /// it - see `Catalog`.
    @State private var listsHiddenRow = false

    /// Which tab of the tabs demonstration is showing, and what that tab has
    /// pushed. Its own path, which is what makes each tab keep its place: the
    /// stacks are separate because the ARRAYS are separate, with nothing in the
    /// library deciding it.
    @State private var tab: DemoTab = .stack
    @State private var tabsPath: [Route] = []

    /// The tabs themselves, in order. State rather than a fixed set, because
    /// the demonstration is a list that CHANGES under a live selection - see
    /// `TabsControls`.
    @State private var tabs: [DemoTab] = DemoTab.opening

    /// What the last change to that list put on the wire, in one line.
    @State private var tabsNote = "nothing has changed the tabs yet"


    /// The last few window lifecycle events, numbered, newest last. The
    /// handlers are the WINDOW's - written on `MainWindow` - so the log lives
    /// where the window does and the Lifecycle sample borrows it.
    @State private var windowEvents: [String] = []

    /// How many lifecycle events have fired since launch: the number in front
    /// of each row, so a repeat plainly reads as a new event.
    @State private var windowEventCount = 0

    /// The gallery's window: what it is called, how big it opens, and the whole
    /// ARRANGEMENT - see Gallery/MainWindow.swift, which is where all of that is
    /// now declared. What is left here is what an application is: the state, and
    /// the list of windows built from it.
    func createWindow() -> Window {
        let nav = navigation

        return MainWindow(
            catalog: Catalog(
                nav: nav,
                listsHiddenRow: $listsHiddenRow,
                windowEvents: $windowEvents),
            nav: nav,
            tabsPath: $tabsPath,
            listsHiddenRow: listsHiddenRow,
            note: note)
    }

    /// Every window the gallery has open: the one above, one per inspector, and
    /// one per document the platform asked for.
    ///
    /// The list is ordinary Swift over ordinary state, and the three kinds are
    /// three TYPES - which is the whole shape of multi-window here: a window is
    /// declared, not configured, so a list of them may hold whichever kinds an
    /// application has.
    ///
    /// Empty of the other two on a phone, which has nowhere to put a second
    /// window - the sample simply does not offer to open one there.
    var windows: [Window] {
        [createWindow()] + inspectorWindows(navigation) + documentWindows(navigation)
    }

    /// The reader asked the PLATFORM for a window - so the gallery describes one
    /// more document, and the window the platform already opened is the one it
    /// appears in.
    ///
    /// One line, and it is the same line `openInspector` runs: the library does
    /// not distinguish a window the interface asked for from a window the system
    /// asked for, because by the time either reaches `windows` there is nothing
    /// to distinguish. Leaving this unwritten is also an answer - the platform's
    /// window is closed again, an application showing the windows it describes.
    var onCreatingWindow: EventHandler? {
        { navigation.openDocument() }
    }

    /// One window per document the platform has been answered with.
    ///
    /// A pure function of what it is handed, like `inspectorWindows` below and
    /// for the same reason: given a `Navigation` over any bindings this builds
    /// the windows those describe, which is what lets a test open one without
    /// reaching into a running application.
    func documentWindows(_ nav: Navigation) -> [Window] {
        nav.documents.map { DocumentWindow(number: $0, nav: nav) }
    }

    /// One window per inspector the application's state holds.
    func inspectorWindows(_ nav: Navigation) -> [Window] {
        nav.inspectors.map { InspectorWindow(number: $0, nav: nav) }
    }

    /// The gallery's navigation over this application's own state.
    ///
    /// A computed value rather than a stored one because it holds nothing: it
    /// is five bindings, made wherever they are needed - in the window build,
    /// and in the inspector windows beside it.
    private var navigation: Navigation {
        Navigation(
            section: $section,
            path: $path,
            menuOpen: $menuOpen,
            sheets: $sheets,
            inspectors: $inspectors,
            documents: $documents,
            tabs: $tabs,
            tab: $tab,
            tabsNote: $tabsNote)
    }

    /// Writes one window event into the log, numbered, keeping the last six -
    /// enough to tell the story without the page growing forever.
    private func note(_ name: String) {
        windowEventCount += 1
        windowEvents = Array((windowEvents + ["\(windowEventCount) · \(name)"]).suffix(6))
    }

    /// The styles every control in the gallery is given - the .NET MAUI
    /// template's own, in Swift. The idiom goes in because one style reads
    /// it: the SearchBar's touch floor is the phone's, not the desktop's.
    /// See Styles/AppStyles.swift.
    var styles: StyleSheet? { AppStyles.sheet(on: device.idiom) }

    /// What the gallery KEEPS between launches - `PersistentStateSample`'s
    /// three settings, and nothing else.
    ///
    /// Listed because a settings store is read one key at a time and offers no
    /// list of what it holds, so this is the only way the host can have the
    /// values in memory before the first view asks for one. Kept in the
    /// platform's own store, which is what an application that leaves
    /// `persistentStorage` alone says.
    var persistentKeys: [PersistentKey] { [.visits, .who, .shade] }
}

/// The one thing this module exports.
///
/// The library cannot declare it: on Android and Windows it is a separate native
/// library, and the dependency runs app -> library, so the library has no way to
/// name an application that did not exist when it was compiled. So the app says
/// which one it is, exactly as a MAUI app does with
/// `builder.UseMauiApp<App>()`.
///
/// The name is fixed by convention (`stateui_app_register`) so the host can
/// find it whatever the module is called.
@_cdecl("stateui_app_register")
public func stateui_app_register() {
    stateUIUseApp(GalleryApp())
}
