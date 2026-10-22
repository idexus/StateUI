# Navigation and presentation

Navigation and presentation are readable application state. StateUI does not
store a second router or command history beside that state. A host materializes
native containers and reports committed user actions back to the same
bindings.

## Navigation stack

`NavigationStack` renders a root page plus one destination for every element of
a typed path:

```swift quote
enum Route: Hashable {
    case note(Int)
    case settings
}

struct MainPage: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack($path) {
            HomePage(path: $path)
        } destination: { route in
            switch route {
            case .note(let id): NotePage(id: id, path: $path)
            case .settings: SettingsPage(path: $path)
            }
        }
    }
}
```

Navigation operations are ordinary array operations:

```swift quote
path.append(.note(42))  // push
path.removeLast()       // pop
path = []               // return to root
```

The root always exists. Each destination is identified by its route and stack
depth, so the same route may appear more than once without sharing page state.
A page position - what a window shows, a stack's root and destinations, a tab,
either half of a split view, a sheet - shows one page: an `if`/`else` or a
`switch` there chooses among pages, each a page of its own, so swapping
branches makes the page anew even where both are the same view. An `if` with
no `else` does not compile there: a position always shows a page. An
arrangement stands there as the page itself, written there or as the `body` of
the view written there, and nowhere else.
A committed native back action truncates the bound path. A cancelled
interactive gesture changes neither the path nor the tree.

Pass the binding to every page that may change the path. A page that receives
only its value can read where it is, but cannot navigate on its owner's behalf.

## Tabs

`TabView` is built from a distinct collection of application values. A
selection binding says which one is showing:

```swift quote
enum Tab: Hashable, CaseIterable {
    case notes, search, settings
}

@State private var selected = Tab.notes

TabView(Tab.allCases, selection: $selected) { tab in
    switch tab {
    case .notes: NotesPage()
    case .search: SearchPage()
    case .settings: SettingsPage()
    }
}
```

Assigning `selected` changes the visible tab. A user-selected tab is reported
into that same binding. Tab identity is the tab value, not its position, so
reordering distinct values retains their pages. Repeating a tab value would
claim one identity twice and is invalid application data.

A tab can contain its own `NavigationStack` and path. That arrangement keeps a
separate stack per tab because each path belongs to the application's state,
not to the tab host.

## Split view

`SplitView` owns two pages - a sidebar and a detail - and a two-way binding
saying whether the sidebar shows:

```swift quote
@State private var menuOpen = false

SplitView($menuOpen, sidebar: {
    MenuPage(showsSidebar: $menuOpen)
}, detail: {
    MainPage()
})
```

The sidebar is a page, so its header, rows, and actions are composed from the
same controls as any other page. StateUI does not require a special menu-item
model. A committed native show or hide writes `menuOpen`; assigning the state
shows or hides the sidebar.

The host adapts presentation to the available space. The state contract stays
the same whether the two pages are temporarily overlaid or persistently side
by side. On AppKit the sidebar runs the window's full height
beside the detail, shown and hidden by the system sidebar button in the
window's toolbar; a window wide enough for both panes opens with the sidebar
shown, and after that the user and the binding decide. On Windows the
sidebar stands beside the detail in a wide window, which opens with it shown;
in a narrow one it opens over the detail from the navigation button beside the
back button in the title bar, and the same button or a click outside it closes
it.
On a phone - iOS and Android alike - the sidebar slides over the detail from
the leading edge, the detail shaded behind it, and a tap on the shade closes
it; on an iPad or a wide tablet it stands beside the detail.

Where the sidebar stands is the host's to say: `.sidebarOverlays($over)`
writes into a state whether it lies over the detail now, as the platform
places it for the room - true on a phone and in a narrow window, false
beside the detail, changing as the window is resized or the device turned.
A sidebar row reads it to close a sidebar lying over the page once the user
has chosen, and to leave one beside the page open:

```swift quote
@State private var menuOpen = false
@State private var menuOverlays = false

SplitView($menuOpen, sidebar: {
    MenuPage(showsSidebar: $menuOpen, overlays: $menuOverlays)
}, detail: {
    MainPage()
})
.sidebarOverlays($menuOverlays)

// In a row of MenuPage:
section = .archive
if overlays { showsSidebar = false }
```

Nothing the application writes into the state reaches the host; it is the
platform's report alone.

What the sidebar stands on is the split view's to say, for each of the two
places, as a `Material` - a color, a gradient, a blur, glass:

```swift quote
SplitView($menuOpen, sidebar: {
    MenuPage(showsSidebar: $menuOpen)
}, detail: {
    MainPage()
})
.sidebarBackground(.blur(.thin))     // beside the detail
.flyoutBackground(.blur(.thick))     // sliding over it
```

Left unsaid, each is the platform's own: beside the detail the window shows
through, as a desktop sidebar does; over it the sidebar stands on the
platform's drawer or overlay surface - never on the window, so a clear window
never leaves a flyout with nothing under its words. The sidebar page's own
`.pageBackground` still paints the page on top. A platform that blurs nothing
inside a window shows a blur as its color.

## Sheets

A view presents a page over the window - a sheet - while a state says so:

```swift
struct NotesPage: View {
    @State private var editing = false

    var body: some View {
        Button("New note")
            .onClicked { editing = true }
            .sheet(isPresented: $editing) {
                VStack {
                    Text("A new note")
                    Button("Done").onClicked { editing = false }
                }
                .padding(24)
            }
    }
}
```

Writing false takes it away. The user takes it away too - a swipe down,
Escape, the system's way back - and that writes false, so the state always
says whether the sheet shows. The view presenting it leaving the screen takes
it away and writes false as well.

A value presents a page made of it: nil takes it away, the user's dismissal
writes nil, and another value presents another page in its place:

```swift
struct Folders: View {
    @State private var opened: String?

    var body: some View {
        VStack {
            Button("Inbox").onClicked { opened = "Inbox" }
            Button("Sent").onClicked { opened = "Sent" }
        }
        .sheet(item: $opened) { name in
            Text(name).padding(24)
        }
    }
}
```

A sheet has no bar of its own. A `NavigationStack` in it brings one - the
stack's titles, its way back, its actions and its colors - and nothing from
around the sheet reaches it:

```swift
struct SettingsButton: View {
    @State private var showsSettings = false
    @State private var path: [String] = []

    var body: some View {
        Button("Settings")
            .onClicked { showsSettings = true }
            .sheet(isPresented: $showsSettings) {
                NavigationStack($path) {
                    Button("Account")
                        .onClicked { path.append("Account") }
                        .title("Settings")
                } destination: { name in
                    Text(name).title(name)
                }
            }
    }
}
```

The stack's bar offers a button closing the sheet - writing false, as every
dismissal does. A page the user must finish rather than leave says it offers
none, as it says whether it offers the way back:

```swift
struct SignUpSheet: View {
    @Binding var shown: Bool
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack($path) {
            Button("Finish")
                .onClicked { shown = false }
                .title("Sign up")
                .showsCloseButton(false)
        } destination: { step in
            Text("Step \(step)")
        }
    }
}
```

A sheet presented in a sheet stands over it, and so does one presented from
beneath while another shows: the last shown is on top. A view holds one
sheet - written again on the same view, the second stands in place of the
first - so two sheets stand on two views. One written on a composed view, a
`Group` or an `if/else` stays as the view's body shows another branch
([What outlives a branch](composition-and-identity.md#what-outlives-a-branch)).
Closing a window takes away every sheet in it.

## Popovers

A view shows what `.popover(isPresented:)` describes in the platform's popover,
by the view, while the state holds true:

```swift
struct FiltersButton: View {
    @State private var filtering = false
    @State private var unreadOnly = false

    var body: some View {
        Button("Filters")
            .onClicked { filtering = true }
            .popover(isPresented: $filtering) {
                VStack {
                    Switch($unreadOnly).text("Unread only")
                    Button("Done").onClicked { filtering = false }
                }
                .spacing(12)
                .padding(16)
            }
    }
}
```

Writing false takes it away. The user takes it away too - a tap or a click
beside it, Escape, the way back - and that writes false to the state, so
the state always says whether the popover shows; the view presenting it
leaving the screen writes false as well. Its content sizes it, and a phone
shows it as a popover too, by the view.

A value shows what the content makes of it: nil takes the popover away, the
user's dismissal writes nil, and another value shows another view in its
place:

```swift
struct Explanations: View {
    @State private var explained: String?

    var body: some View {
        HStack {
            Button("Sync").onClicked { explained = "Sync keeps your mail the same everywhere." }
            Button("Backup").onClicked { explained = "Backup saves a copy every night." }
        }
        .popover(item: $explained) { words in
            Text(words).padding(16)
        }
    }
}
```

A popover written on a composed view, a `Group` or an `if/else` stays as the
view's body shows another branch, by the view it shows
([What outlives a branch](composition-and-identity.md#what-outlives-a-branch)).

## Over every page

A view declares what it lays over the window with `.overlays { }`, built
with the state it follows - a notice comes and goes with its state:

```swift
struct OfflineNotice: View {
    @Binding var shown: Bool

    var body: some View {
        HStack {
            Text("Working offline")
            Button("Dismiss").onClicked { shown = false }
        }
        .spacing(12)
        .horizontalAlignment(.center)
        .verticalAlignment(.start)
    }
}

struct LibraryPage: View {
    @State private var offline = false

    var body: some View {
        Switch($offline)
            .overlays {
                if offline {
                    OfflineNotice(shown: $offline)
                }
            }
    }
}
```

Declared on a window's page, the overlays stand over every page the window
shows and every sheet over it, and live as long as the window; declared on a
page, they stand while that page is shown and go with it - a page pushed over
it takes them away, and going back brings them again. Those declared further
in stand over those declared around them, and `.zIndex` reorders the views of
one declaration. Each view has the window's whole area and stands where its
alignments put it. A click beside it goes on to what is under it. A docked
inspector stands over every overlay.

## Page titles and navigation furniture

A view shown as a page says what its page is by modifier - `.title("Notes")`
([What a view says of its page](application-and-sessions.md#what-a-view-says-of-its-page)).
An arrangement is a page already, and takes its title and icon the same way:

```swift quote
NavigationStack($settingsPath) {
    SettingsHome(path: $settingsPath)
} destination: { route in
    SettingsDestination(route: route)
}
.title("Settings")
.icon("settings.png")
```

The container's title and icon describe it when it is an item in another
container, such as a tab. The title shown for the top page of a navigation
stack is the one its own view says.

A view such as `SearchField` can stand in the page's title slot, declared where
the state it follows lives:

```swift quote
@State private var query = ""

VStack { … }
    .titleView {
        SearchField($query)
            .placeholder("Search")
    }
```

Declared on a stack or a window's page, a title view stands on every page shown
there that declares none of its own; the innermost declaration wins.

## Toolbars

A page's actions are declared where the state they follow lives, with
`.toolbar { }` on the page's view:

```swift quote
VStack { … }
    .toolbar {
        ToolbarItem("Save")
            .id("save")
            .isEnabled(hasChanges)
            .onClicked(gate: .ignoreWhileRunning) { try await save() }
        ToolbarItem("Delete")
            .id("delete")
            .placement(.overflow)
            .role(.destructive)
            .onClicked(gate: .ignoreWhileRunning) { try await delete() }
    }
```

The group is built with the body declaring it, so an item follows the state it
reads - Save enables itself as `hasChanges` moves, with nothing written by hand.
It stands on the bar while its page is shown, and when the page goes, its
actions go with it.

One declaration is one group: its actions share one background where the
platform groups a bar's actions, as macOS and iOS draw them on one piece of
glass. A second group is a second declaration. A group stands at the bar's
end unless `.toolbar(.start)` puts it at its start.

A window's page and an arrangement declare actions for every page shown in
them. The actions declared further in join them nearer the title, so the
outer ones keep their place at the edge from page to page:

```swift quote
NavigationStack($path) {
    Library(path: $path)
} destination: { book in
    BookPage(book: book)
}
.toolbar(id: "library") {
    ToolbarItem("Account").onClicked { showAccount() }
}
```

`order` moves a group earlier or later among the others at its edge, lower
first. `.toolbar(id:)` adds a page's actions to the group of that id instead of
starting one of its own, and an item with the `.id` of one declared further out
stands in that item's place while its page is shown. `placement` keeps an
action on the bar or behind the native overflow. Give stable identities to
items whose list can change.

An item given an `icon` shows the picture alone on the bar; its words stay its
name to assistive technology and its tip. `showsText(true)` asks for the words
beside the picture where the platform's bar shows both - WinUI and GTK for each
item, Android where the bar has room. A Mac leaves that choice to the user,
through the toolbar's own display mode, and an iPhone's bar shows a picture or
words, so there the item keeps its picture alone. An item with no picture
always shows its words.

```swift quote
VStack { … }
    .toolbar {
        ToolbarItem("Add")
            .icon("add.png")
            .showsText(true)
            .onClicked { add() }
    }
```

On AppKit a page's furniture is its window's toolbar: the top page's title
names the window, the way back is the system's back item, the actions are
toolbar items - a space between two groups, a group at the start before the
flexible space - and those placed in the overflow sit in the toolbar's
overflow menu. Android's bar has no start beside its navigation button, so a
group at the start stands first among its actions. On AppKit, a tabbed
view on the window's page path shows its tabs in a row beneath the toolbar,
beside any sidebar, the tabs sharing its width with each picture beside its
title; one in a sidebar, a sheet or inside another tab is a tab view with its
tabs on the top edge of its content.

Every arrangement accepts a flat `barBackgroundColor` and a `barForegroundColor`
for its title and native action affordances; a page's bar takes each from the
nearest arrangement around it that declares one, so a stack further in paints
its own - a sidebar takes only what its own split view declares, and a sheet
has no bar until a stack in it brings one, painted as that stack says. The
application's name, the line under the title and its mark are declared the same
way ([The window's bar](application-and-sessions.md#the-windows-bar)). Native tab
selectors keep their selected and unselected states, legible over a written
background. Leaving the background unwritten preserves the platform's
material. A written color is
painted where the bars stand and nowhere else - on AppKit the band the title
bar and toolbar cover, under a floating sidebar's glass too, with the page's
title in `barForegroundColor` on it - while the toolbar's own items keep the
system's look. What the window shows around the bars is its own background
(`window.background`). Gradients
remain ordinary view composition where the application owns the surface.

Where the host draws the bar's buttons itself - the Web - `toolbarStyle` says
how they stand: `.glass`, each on a round glass; `.plain`, no background until
the pointer is over one; `.rounded`, a flat rounded rectangle; or the
platform's own, `.system`, unless said - plain on the Web.
`barButtonBackgroundColor` is the color behind them. Both are found along the
path as the bar's colors are, and native bars keep their platform's buttons:

```swift
struct NotesPage: View {
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack($path) {
            Text("Notes")
        } destination: { _ in
            Text("Note")
        }
        .toolbarStyle(.rounded)
        .barButtonBackgroundColor(Color(hex: 0xD5E0E4))
    }
}
```

## Menu bars and context menus

A page's menus are declared like its actions, with `.menuBar { }` on the
page's view, and stand on the desktop menu bar while the page is shown:

```swift quote
VStack { … }
    .menuBar {
        Menu("File") {
            MenuItem("Save")
                .id("save")
                .isEnabled(hasChanges)
                .onClicked(gate: .ignoreWhileRunning) { try await save() }
            Menu("Recent") {
                recent.map { file in
                    MenuItem(file.name)
                        .id(file.id)
                        .onClicked { open(file) }
                }
            }
        }
        .id(StandardMenu.file)
    }
```

A window's page and an arrangement declare menus for every page shown in
them. A menu with the `.id` of one declared further out joins it: its
entries stand after that menu's as a section of their own, after a line, and
an entry with the `.id` of an entry there stands in that entry's place while
its page is shown - a window's disabled Save becomes the document page's own,
and the window's comes back as the page goes. Other menus follow the ones
declared further out, before the platform's Window and Help; `order` moves a
declaration's menus and sections earlier or later, lower first.

```swift quote
SplitView($sidebar) {
    Library()
} detail: {
    Welcome()
}
.menuBar {
    Menu("File") {
        MenuItem("Save")
            .id("save")
            .isEnabled(false)
    }
    .id(StandardMenu.file)
}
```

The platform's own menus are joined by identity, never by caption:
`.id(StandardMenu.file)` - `edit`, `view`, `window`, `help` - puts a menu's
entries into AppKit's File menu and UIKit's `.file` menu after the platform's
own, whatever the menu is called, so "Plik" joins it too. On WinUI it is an
ordinary menu of the application's; on GTK, a submenu of the header bar's main
menu. An Edit menu holds the platform's own entries on every host that shows
it: AppKit's and iPadOS's Edit menu, and on WinUI, GTK and the Web the same
entries StateUI keeps - Undo, Redo, Cut, Copy, Paste, Delete and Select All,
in the system's language, acting on the field the user typed into though the
menu took the focus - with the page's entries after them. Android keeps no menu bar: a page's menus stand behind its stack's
bar's overflow, each a submenu after the actions. An iPhone shows no menu
bar. `Menu` holds only `MenuItem`, `Menu` and `MenuSeparator`, and a menu bar
only `Menu`: anything else does not compile.

A menu bar stands only while something declares a menu. On WinUI a window
shows its menu bar, and on GTK its page's header bar its main menu, while that
page, or an arrangement around it, declares a menu, and none at all otherwise;
macOS and iPadOS always keep the platform's own menus, which a declared menu
joins. So declare a menu where its entries act - File on the page that saves -
and around every page only what every page offers: a menu declared on the
window's page stands over every page, even where it holds nothing the page
can do.

The same item vocabulary can be attached to any view as a context menu:

```swift quote
Text(document.title)
    .contextMenu {
        MenuItem("Duplicate").onClicked { duplicate(document) }
        MenuItem("Delete")
            .role(.destructive)
            .onClicked { delete(document) }
    }
```

An item may stand for a setting: given `isOn`, it shows the platform's check,
and given a binding, choosing it turns the state over before its `onClicked`
runs:

```swift
struct Page: View {
    @State private var showsRuler = false

    var body: some View {
        Text("Draft")
            .contextMenu {
                MenuItem("Show Ruler").isOn($showsRuler)
            }
    }
}
```

`.onToggled` hears each turn with the way it turned to. An item that says
neither way shows no check and is only clicked.

On an item of an `ItemsView` the context menu is the item's actions, declared
once: a platform that swipes a list's items - UIKit - offers its items the
user can choose as the item's swipe actions too, a destructive one in its
destructive style; every platform offers the menu itself.

Menu and toolbar structures are reconciled by identity like other ordered
children. A platform without that surface may omit its presentation; never put
the only route to an essential action behind a context menu. Consult
[Platform contract](../platform-contract.md) for verified support.
