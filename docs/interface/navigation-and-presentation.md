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

struct MainWindow: Window {
    @State private var path: [Route] = []

    var page: any Page {
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
A page position - a window's page, a stack's root and destinations, a tab,
either half of a split view, a sheet - shows one page: an `if`/`else` or a
`switch` there chooses among pages, each a page of its own, so swapping
branches makes the page anew even where both are the same view. An `if` with
no `else` does not compile there: a position always shows a page.
A committed native back action truncates the bound path. A cancelled
interactive gesture changes neither the path nor the tree.

Pass the binding to every page that may change the path. A page that receives
only its value can read where it is, but cannot navigate on its owner's behalf.

## Tabs

`TabbedView` is built from a distinct collection of application values. A
selection binding says which one is showing:

```swift quote
enum Tab: Hashable, CaseIterable {
    case notes, search, settings
}

@State private var selected = Tab.notes

TabbedView(Tab.allCases) { tab in
    switch tab {
    case .notes: NotesPage()
    case .search: SearchPage()
    case .settings: SettingsPage()
    }
}
.selection($selected)
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
    MenuPage(isSidebarVisible: $menuOpen)
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
sidebar opens over the detail from the navigation button beside the back
button in the title bar, and the same button or a click outside it closes it.
On a phone - iOS and Android alike - the sidebar slides over the detail from
the leading edge, the detail shaded behind it, and a tap on the shade closes
it; on an iPad or a wide tablet it stands beside the detail.

## Modal pages

Modal presentation is an arrangement of an application array, `ModalStack`,
standing as a window's page: the page it holds first, and a page presented
over it for each element of the array:

```swift
enum Sheet: Hashable {
    case settings
    case about
}

struct Home: ContentView {
    @Binding var sheets: [Sheet]

    var content: some View {
        Button("Settings").onClicked { sheets.append(.settings) }
    }
}

struct Presented: ContentView {
    let title: String
    @Binding var sheets: [Sheet]

    var content: some View {
        VStack {
            Label(title)
            Button("Close").onClicked { sheets.removeLast() }
        }
    }
}

struct MainWindow: Window {
    @State private var sheets: [Sheet] = []

    var page: any Page {
        ModalStack($sheets) {
            Home(sheets: $sheets)
        } destination: { sheet in
            switch sheet {
            case .settings: Presented(title: "Settings", sheets: $sheets)
            case .about: Presented(title: "About", sheets: $sheets)
            }
        }
    }
}
```

Appending presents, removing dismisses, and the last element is on top. A
native dismissal truncates the bound array to the number of pages still
presented. A modal page therefore carries its own dismissal route by receiving
the binding. The stack is the window's page, so its sheets stand over
everything the window shows; closing the window tears down every page it
presents.

## Over every page

A view declares what it lays over the window with `.overlays { }`, built
with the state it follows - a notice comes and goes with its state:

```swift
struct OfflineNotice: ContentView {
    @Binding var shown: Bool

    var content: some View {
        HStack {
            Label("Working offline")
            Button("Dismiss").onClicked { shown = false }
        }
        .spacing(12)
        .horizontalAlignment(.center)
        .verticalAlignment(.start)
    }
}

struct LibraryPage: ContentView {
    @State private var offline = false

    var content: some View {
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

A view shown as a page changes its `PageSession`. An arrangement is a page
already, with no session of its own, so it is told what it is by modifier:

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
stack comes from that page's own `PageSession`.

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
            .onClicked { try await save() }
        ToolbarItem("Delete")
            .id("delete")
            .placement(.overflow)
            .isDestructive(true)
            .onClicked { try await delete() }
    }
```

The group is built with the body declaring it, so an item follows the state it
reads - Save enables itself as `hasChanges` moves, with nothing written by hand.
It stands on the bar while its page is shown, and when the page goes, its
actions go with it.

One declaration is one group: its actions share one background where the
platform groups a bar's actions, as macOS and iOS draw them on one piece of
glass. A second group is a second declaration. A group stands at the bar's
trailing edge unless `.toolbar(.leading)` puts it at the other.

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
toolbar items - a space between two groups, a leading group before the
flexible space - and those placed in the overflow sit in the toolbar's
overflow menu. Android's bar has no leading edge beside its navigation button,
so a leading group stands first among its actions. A tabbed
view on the window's page path shows its tabs in a row beneath the toolbar,
beside any sidebar, the tabs sharing its width with each picture beside its
title; one in a sidebar, a sheet or inside another tab is a tab view with its
tabs on the top edge of its content.

Every arrangement accepts a flat `barBackgroundColor` and a `barForegroundColor`
for its title and native action affordances; a page's bar takes each from the
nearest arrangement around it that declares one, so a stack further in paints
its own - a sidebar and a sheet take nothing from around them. The
application's name, the line under the title and its mark are declared the same
way ([The window's bar](application-and-sessions.md#the-windows-bar)). Native tab
selectors keep their selected and unselected states, legible over a written
background. Leaving the background unwritten preserves the platform's
material. A written colour is
painted where the bars stand - on AppKit the band the title bar and toolbar
cover over the visible content, with the page's title in `barForegroundColor` on it,
and the window's background, which a Mac shows around a floating sidebar and
through its glass - while the toolbar's own items keep the system's look. On a
translucent window the colour tints the window's material instead. Gradients
remain ordinary view composition where the application owns the surface.

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
                .onClicked { try await save() }
            Menu("Recent") {
                ForEach(recent) { file in
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
own, whatever the menu is called, so "Plik" joins it too. On WinUI and GTK it
is an ordinary menu of the application's. Android keeps no menu bar: a page's
menus stand behind its stack's bar's overflow, each a submenu after the
actions. An iPhone shows no menu bar. `Menu`
holds only `MenuItem`, `Menu` and `MenuSeparator`, and a menu bar only `Menu`:
anything else does not compile.

A menu bar stands only while something declares a menu. On WinUI and GTK a
window shows its menu bar while its page, or an arrangement around that page,
declares one, and none at all otherwise; macOS and iPadOS always keep the
platform's own menus, which a declared menu joins. So declare a menu where its
entries act - File on the page that saves - and around every page only what
every page offers: a menu declared on the window's page stands over every
page, even where it holds nothing the page can do.

The same item vocabulary can be attached to any view as a context menu:

```swift quote
Label(document.title)
    .contextMenu {
        MenuItem("Duplicate").onClicked { duplicate(document) }
        MenuItem("Delete")
            .isDestructive(true)
            .onClicked { delete(document) }
    }
```

Menu and toolbar structures are reconciled by identity like other ordered
children. A platform without that surface may omit its presentation; never put
the only route to an essential action behind a context menu. Consult
[Platform contract](../platform-contract.md) for verified support.
