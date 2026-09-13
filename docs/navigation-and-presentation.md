# Navigation and presentation

Navigation and presentation are readable application state. StateUI does not
store a second router or command history beside that state. A host materializes
native containers and reports committed reader actions back to the same
bindings.

## Navigation stack

`NavigationPage` renders a root page plus one destination for every element of
a typed path:

```swift quote
enum Route: Hashable {
    case note(Int)
    case settings
}

struct MainWindow: Window {
    @State private var path: [Route] = []

    var page: any Page {
        NavigationPage($path) {
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
A committed native back action truncates the bound path. A cancelled
interactive gesture changes neither the path nor the tree.

Pass the binding to every page that may change the path. A page that receives
only its value can read where it is, but cannot navigate on its owner's behalf.

## Tabs

`TabbedPage` is built from a distinct collection of application values. A
selection binding says which one is showing:

```swift quote
enum Tab: Hashable, CaseIterable {
    case notes, search, settings
}

@State private var selected = Tab.notes

TabbedPage(Tab.allCases) { tab in
    switch tab {
    case .notes: NotesPage()
    case .search: SearchPage()
    case .settings: SettingsPage()
    }
}
.selection($selected)
```

Assigning `selected` changes the visible tab. A reader-selected tab is reported
into that same binding. Tab identity is the tab value, not its position, so
reordering distinct values retains their pages. Repeating a tab value would
claim one identity twice and is invalid application data.

A tab can contain its own `NavigationPage` and path. That arrangement keeps a
separate stack per tab because each path belongs to the application's state,
not to the tab host.

## Flyout

`FlyoutPage` owns two pages and a two-way presentation binding:

```swift quote
@State private var menuOpen = false

FlyoutPage($menuOpen, flyout: {
    MenuPage(isPresented: $menuOpen)
}, detail: {
    MainPage()
})
```

The flyout is a page, so its header, rows, and actions are composed from the
same controls as any other page. StateUI does not require a special menu-item
model. A committed native open or dismiss gesture writes `menuOpen`; assigning
the state presents or dismisses it.

The host adapts presentation to the available space. The state contract stays
the same whether the two pages are temporarily overlaid or persistently side
by side.

## Modal pages

Modal presentation belongs to the window. `ModalStack` maps an application
array to pages and is installed in `WindowSession`:

```swift quote
enum Sheet: Hashable {
    case settings
    case rename
}

@State private var sheets: [Sheet] = []
@Environment private var window: WindowSession

.onCreated {
    window.modalStack = ModalStack($sheets) { sheet in
        switch sheet {
        case .settings: SettingsPage(sheets: $sheets)
        case .rename: RenamePage(sheets: $sheets)
        }
    }
}
```

Appending presents, removing dismisses, and the last element is on top. A
native dismissal truncates the bound array to the number of pages still
presented. A modal page therefore carries its own dismissal route by receiving
the binding.

The stack belongs to the window rather than to whichever page happened to
present it. Replacing or closing that window tears down every modal it owns.

## Page titles and navigation furniture

A written `ContentPage` changes its `PageSession`. Container pages created by
StateUI use modifiers because they have no independent content-page session:

```swift quote
NavigationPage($settingsPath) {
    SettingsHome(path: $settingsPath)
} destination: { route in
    SettingsDestination(route: route)
}
.title("Settings")
.iconImageSource("settings.png")
```

The container's title and icon describe it when it is an item in another
container, such as a tab. The title shown for the top page of a navigation
stack comes from that page's own `PageSession`.

A view such as `SearchBar` can occupy the current page's navigation title slot:

```swift quote
@Environment private var page: PageSession
@State private var query = ""

.onCreated {
    page.navigationPageTitleView = SearchBar($query)
        .placeholder("Search")
}
```

## Toolbars

Toolbar items are page furniture, not views in page layout:

```swift quote
@Environment private var page: PageSession

page.toolbarItems = [
    ToolbarItem("Save")
        .id("save")
        .priority(0)
        .onClicked { try await save() },
    ToolbarItem("Delete")
        .id("delete")
        .order(.secondary)
        .isDestructive(true)
        .onClicked { try await delete() },
]
```

`order` distinguishes primary actions from actions behind native overflow.
Within either group, lower `priority` appears first and equal values retain
source order. The host chooses the native placement appropriate to the window
and available space. Give stable identities to items whose list can change.

Page arrangements accept a flat `barBackgroundColor`. A `NavigationPage` also
accepts `barTextColor` for its title and native action affordances. Native tab
selectors retain their selected and unselected state appearance. Leaving the
background unwritten preserves the platform's material. Gradients remain
ordinary view composition where the application owns the surface.

## Menu bars and context menus

Desktop menu bars are also stored on `PageSession`:

```swift quote
page.menuBarItems = [
    MenuBarItem("File") {
        MenuFlyoutItem("Save").onClicked { try await save() }
        MenuFlyoutSeparator()
        MenuFlyoutSubItem("Recent") {
            ForEach(recent) { file in
                MenuFlyoutItem(file.name)
                    .id(file.id)
                    .onClicked { open(file) }
            }
        }
    }
    .id("file"),
]
```

The same item vocabulary can be attached to any view as a context menu:

```swift quote
Label(document.title)
    .contextFlyout {
        MenuFlyoutItem("Duplicate").onClicked { duplicate(document) }
        MenuFlyoutItem("Delete")
            .isDestructive(true)
            .onClicked { delete(document) }
    }
```

Menu and toolbar structures are reconciled by identity like other ordered
children. A platform without that surface may omit its presentation; never put
the only route to an essential action behind a context menu. Consult
[Platform contract](platform-contract.md) for verified support.
