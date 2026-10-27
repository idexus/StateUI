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

The split view's bar offers the platform's toggle for the sidebar - the
toolbar's sidebar button on a Mac, the navigation button in a Windows title
bar, ☰ at the start of a phone's bar - unless `.showsSidebarToggle(false)`
takes it away. A value from a state keeps it to some pages, as to the root
of the detail's stack, leaving a page pushed over it the way back alone:

```swift quote
@State private var path: [Route] = []

SplitView($menuOpen, sidebar: {
    MenuPage(showsSidebar: $menuOpen)
}, detail: {
    NavigationStack($path) { InboxPage() } destination: { MailPage($0) }
})
.showsSidebarToggle(path.isEmpty)
```

With no toggle the sidebar shows and hides by its binding - and by an edge
swipe where the platform has one, as iOS does; elsewhere the application's
own button is then the way in.

What the sidebar stands on is the split view's to say, for each of the two
places, as a `Material` - a color, a gradient, a blur, glass:

```swift quote
SplitView($menuOpen, sidebar: {
    MenuPage(showsSidebar: $menuOpen)
}, detail: {
    MainPage()
})
.sidebarBackground(.blur(.thin))          // beside the detail
.sidebarOverlayBackground(.blur(.thick))  // sliding over it
```

Left unsaid, beside the detail the window shows through, as a desktop sidebar
does; over it the sidebar stands on the window's background
(`window.background`) laid over the platform's drawer or overlay surface, so
the window's color reaches it and a clear window never leaves a sidebar over
the page with nothing under its words. A window saying no background leaves
the platform's own surface there. The sidebar page's own
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

On a wide screen a sheet stands as large as its page asks, within the
platform's bounds; a page taller than they allow scrolls inside it. A sheet
holding a stack, tabs or a split view - whose pages come and go - or a view
that takes the room it is given, such as a list or a map, stands at the
platform's standard size. On a phone a sheet rises from the bottom.

A sheet stands on its window's background (`window.background`), laid over
the platform's own sheet, so the application's color reaches the sheet as it
reaches its pages, and its words keep an opaque surface however clear the
window is. A window saying no background leaves the platform's own sheet.

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
stack's titles, its way back and its actions, nothing of them from around the
sheet - in the look of the bar over the view presenting the sheet, unless the
stack declares its own:

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
stack is the one its own view says. Its `.pageBackground` is what each of its
pages that says none stands on - the nearest arrangement's, as a bar's look
is - so a stack in a sheet grounds every page it pushes with one modifier:

```swift quote
NavigationStack($path) {
    DraftPage()
} destination: { step in
    StepPage(step)
}
.pageBackground(.color(paper))
```

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
        ToolbarButton("Save")
            .id("save")
            .isEnabled(hasChanges)
            .onClicked(.ignoreWhileRunning) { try await save() }
        ToolbarButton("Delete")
            .id("delete")
            .placement(at: .overflow)
            .role(.destructive)
            .onClicked(.ignoreWhileRunning) { try await delete() }
    }
```

The items are built with the body declaring them, so an item follows the state
it reads - Save enables itself as `hasChanges` moves, with nothing written by
hand. They stand on the bar while their page is shown, and when the page goes
its actions go with it: a page pushed onto a stack shows its own and none of
the page under it, and a `NavigationStack` or a `TabView` declares none -
`.toolbar` written on one is left out, and said once.

Each item says where it stands with `.placement` - at the bar's `.start`, its
`.end`, unsaid, or behind its `.overflow` menu - and an `order` among the
others there, lower first; at the same order a page's views further out stand
at the edge and those further in nearer the title. A `ToolbarGroup` stands its
items together on one background where the platform groups a bar's actions, as
macOS and iOS draw them on one piece of glass, and behind the overflow it is a
section of the menu; an item standing alone is a group of one, and an item in
a group stands where its group does:

```swift quote
VStack { … }
    .toolbar {
        ToolbarGroup {
            ToolbarButton("Bold").onClicked { bold() }
            ToolbarButton("Italic").onClicked { italic() }
        }
        .placement(at: .start)
        ToolbarButton("Share").onClicked { share() }
    }
```

A split view stands under one bar in two parts, over its sidebar and over its
detail. A page's items stand in its own column's part, and a split view's own
over every page of the part they name - the detail's, unsaid - beside the
page's own, at the edge. An item naming the other part stands there, and one
whose part changes moves to it. While the sidebar is not shown its part's items
stand at the start of the detail's, or hide with it where they say
`hidesWithSidebar(true)`:

```swift
import StateUI

struct Library: View {
    @State private var showsFolders = true

    var body: some View {
        SplitView($showsFolders) {
            Text("Folders").title("Library")
        } detail: {
            Text("Books").title("All books")
        }
        .toolbar {
            ToolbarButton("Add folder").placement(.sidebar).hidesWithSidebar(true).onClicked {}
            ToolbarButton("Account").onClicked {}
        }
    }
}
```

A part said on a page that stands in no split view changes nothing. Give stable
identities to items whose list can change.

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
        ToolbarButton("Add")
            .icon("add.png")
            .showsText(true)
            .onClicked { add() }
    }
```

A setting on the bar is a `ToolbarToggle`: on or off as its `isOn` says, and
given a binding, choosing it turns the state over. It stands as the
platform's two-state button - selected on iOS, an `AppBarToggleButton` on
Windows, a toggle button in GNOME's header bar, a pressed button on the Web -
and shows its `on:` picture while it is on; behind the overflow it stands
checked or not, as a `MenuToggle` does in a menu. A Mac's toolbar item holds
no state of its own: it shows the on picture, and one with none stands out
while on; Android's bar shows the state by the on picture alone.

```swift quote
@State private var showsInspector = false

VStack { … }
    .toolbar {
        ToolbarToggle("Inspector", isOn: $showsInspector)
            .icon("sidebar.png", on: "sidebar_filled.png")
    }
```

A `ToolbarButton` holds a menu as a button does
([A button's menu](interaction-and-actions.md#a-buttons-menu)): with no
`.onClicked` its click opens it, an arrow saying so unless `showsMenuArrow(false)`;
with one it splits, its click its own and its menu beside it; `.held` opens the
menu as the button is held. Behind the overflow it is a submenu under its words,
its own action first. A Mac draws the arrow on its toolbar's menu item, GTK and
the Web on theirs; iOS, Android and WinUI draw none on a bar. A bar that has no
split part - iOS and WinUI - opens a split item's menu held, and Android puts it
behind the overflow, the item's action on the bar.

```swift quote
@State private var order = "A to Z"

VStack { … }
    .toolbar {
        ToolbarButton("Sort").menu {
            MenuItem("A to Z").onClicked { order = "A to Z" }
            MenuItem("Z to A").onClicked { order = "Z to A" }
        }
        ToolbarButton("Save")
            .onClicked { save() }
            .menu { MenuItem("Save a copy").onClicked { saveCopy() } }
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

Every arrangement accepts a `barBackground` - a `Material`: a color, a
gradient, a blur, glass - and a `barForegroundColor` for its title and native
action affordances; a page's bar takes each from the nearest arrangement
around it that declares one, so a stack further in paints its own - a sidebar
takes only what its own split view declares, and a stack in a sheet takes the
look of the bar over the view presenting the sheet. What the bar says is each
page's own ([The window's bar](application-and-sessions.md#the-windows-bar)).
Native tab selectors keep their selected and unselected states, legible over a
written background. Leaving the background unwritten preserves the platform's
material. A blur is the platform's own where its bars blur - iOS, iPadOS,
WinUI's acrylic, the Web's backdrop filter - and its color elsewhere; glass is
the platform's own bar where it has one. A gradient runs across each bar the
platform draws, its points fractions of that bar: in a split view one across
the window where one bar spans it - AppKit's band, beneath a floating
sidebar's glass and over the detail, and WinUI's title bar - and one in each
pane where each pane has a bar of its own, on the iPad and GTK. Words
with no color written stand light on a dark gradient and dark on a light one,
by its colors on the whole. A written material stands where the
bars stand and nowhere else - on AppKit the band the title bar and toolbar
cover, under a floating sidebar's glass too, with the page's title in
`barForegroundColor` on it - while the toolbar's own items keep the system's
look. What the window shows around the bars is its own background
(`window.background`).

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

The weight of the words on the bar's buttons is every platform's to draw but
the Mac's, whose toolbar items draw their own titles: `barButtonFontWeight`
gives it - `.regular`, `.medium`, `.semibold` or `.bold` - and nil, as
unsaid, the platform's own, even under an arrangement around it that gives
one. It is found along the path as the bar's colors are:

```swift
struct InboxPage: View {
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack($path) {
            Text("Inbox")
                .toolbar { ToolbarButton("Archive") }
        } destination: { _ in
            Text("Message")
        }
        .barButtonFontWeight(.semibold)
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
                .onClicked(.ignoreWhileRunning) { try await save() }
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

A setting's entry is a `MenuToggle`: it shows the platform's check as its
`isOn` says, and given a binding, choosing it turns the state over:

```swift
struct Page: View {
    @State private var showsRuler = false

    var body: some View {
        Text("Draft")
            .contextMenu {
                MenuToggle("Show Ruler", isOn: $showsRuler)
            }
    }
}
```

`.onToggled` hears each turn with the way it turned to. A `MenuItem` acts:
it shows no check, and choosing it runs its `onClicked`.

On an item of an `ItemsView` the context menu is the item's actions, declared
once: a platform that swipes a list's items - UIKit - offers its items the
user can choose as the item's swipe actions too, a destructive one in its
destructive style; every platform offers the menu itself.

Menu and toolbar structures are reconciled by identity like other ordered
children. A platform without that surface may omit its presentation; never put
the only route to an essential action behind a context menu. Consult
[Platform contract](../platform-contract.md) for verified support.
