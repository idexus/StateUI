# Applications and sessions

StateUI separates structural declarations from the identity-bearing objects
that exist while an application runs:

```text
declaration                     runtime state
-----------                     ------------------
Application                     ApplicationSession
Scene                           SceneSession
WindowGroup, Window             WindowSession
```

A declaration answers what it is composed of. Its session answers what the
particular running instance is called, where it stands in its lifecycle, and
what actions can be taken on it. Sessions are ordinary objects with `@State`
properties, read by name: `@Environment(\.application)`, `\.scene`,
`\.window`. The page a view stands on
has no session: what it is, its view says by modifier
([What a view says of its page](#what-a-view-says-of-its-page)).

## Application

An application's `body` lists its scenes. Where its windows share nothing,
that is a `WindowGroup` showing a view: launch opens one window of it, and
*File ▸ New Window* one more.

```swift
struct SingleWindowApp: Application {
    var body: some Scene {
        WindowGroup { HomePage() }
    }
}

struct HomePage: View {
    var body: some View { Text("Home") }
}
```

`Application` is a protocol with one property, `var body: some Scene`. The body
lists scenes: a type of the application's own conforming to `Scene`, or a
`WindowGroup` or `Window` written there, which is a scene of its own. A view
written there does not compile, because a view stands in a window. The
application is made once, at its first need, and kept for the life of the
process, so a `@State` it declares outlives every window; what every scene
shares belongs to it, offered to a scene with `.environment(_:)` on the
scene ([Scenes](#scenes)).

`ApplicationSession` owns process-wide policy and reports process-wide state:

| Member | Meaning |
| --- | --- |
| `phase` | active, inactive, or background |
| `info` | what the host says the application is, an `AppInfo`: `name`, `packageName`, `versionString`, `buildString`, `colorScheme`, the theme in force, and `accentColor`, the accent the user chose for the system, both kept current as the user switches them ([What the library offers](../concepts/environment.md#what-the-library-offers)) |
| `colorScheme` | the theme the application holds: `.system` follows the user, `.light` and `.dark` hold it ([The application's theme](#the-applications-theme)) |
| `scenes` | the scenes standing, in opening order |
| `styles` | the application's `StyleSheet` |
| `motion` | default motion law |
| `persistentKeys` | state keys hydrated before the first description |
| `openWindow()` | opens one more window of the `WindowGroup` with no name, as *File ▸ New Window* does |
| `openWindow(_:)`, `openWindow(_:value:)` | opens a window of a kind, in the scene declaring it |
| `closeWindow(_:)`, `closeWindow(_:value:)` | closes every window of a kind, or the one for a value |

### The application's theme

An application follows the theme the user chose until it holds one of its
own. `application.colorScheme` is `.system` until it is written; `.light` or
`.dark` shows every window in that theme with each platform's own call, and
`.system` gives it back to the user's setting. `info.colorScheme` reports the
theme in force, which every `Color(light:dark:)` resolves against.

```swift quote
Button("Dark") { application.colorScheme = .dark }
Button("As the system") { application.colorScheme = .system }
```

`info.accentColor` is the accent the user chose for the system - on a
platform with none, the application's own tint - reported live, so a view
reading it is built again when the user changes it.

```swift quote
Switch($on).tint(app.info.accentColor)
```

Configuration needed before the first view is built belongs in the
application's initializer:

```swift quote
struct NotesApp: Application {
    @Environment(\.application) private var application

    init() {
        application.styles = AppStyles.sheet
        application.motion = .spring(response: 300)
        application.persistentKeys = [.lastDocument]
    }

    var body: some Scene { NotesScene() }
}
```

## Scenes

A scene is a set of windows and the state they share. Each scene the
application declares stands at most once: it opens with its first window and
ends with its last, and its state goes with it.

`Scene` is a protocol with one property, `var body: some Scene`, which lists
the scene's windows in any number and order; a view or another scene written
there does not compile. No window is a main one: the window launch opens is
one window of the `WindowGroup` with no name, like any other, and closing it
closes that window alone.

```swift quote
extension WindowType {
    static let inspector = WindowType("notes.inspector")
    static let document = WindowType("notes.document")
}

struct NotesScene: Scene {
    @State private var library = Library()

    var body: some Scene {
        WindowGroup { NotesPage() }
            .environment(library)
        Window(.inspector) { InspectorPage() }
            .environment(library)
        WindowGroup(.document, for: Int.self) { number in
            DocumentPage(number: number)
        }
    }
}
```

A scene declares its windows three ways:

- `WindowGroup { ... }` with no name - one in the application - is the window
  launch opens, and *File ▸ New Window* makes one more of it;
- `WindowGroup(.kind) { ... }` makes as many windows of the kind as are
  opened, and `Window(.kind) { ... }` makes one;
- `WindowGroup(.kind, for: ID.self) { $id in ... }` makes one window per
  value. The value is `Codable` and `Hashable` so it can identify and restore
  the window, and the closure receives a `Binding`, so the same window can be
  retargeted without replacing its session.

Every window of a scene shares the scene's `@State`. What belongs to one
window is the `@State` of the view it shows: two windows of `NotesPage` each
keep a place of their own, and both read the scene's `library`. An object
reaches the views of a window by `.environment(_:)` on its `WindowGroup` or
`Window`, and every window of a scene by `.environment(_:)` on the scene where
the application's body names it; a nearer one of the same type overrides it
for its own branch. What a window shows may change; which windows a scene
declares may not.

A window belongs to the scene declaring its kind. A window that belongs to
none of the others - About, the preferences - is a scene of its own:

```swift
import StateUI

extension WindowType {
    static let editor = WindowType("notes.editor")
    static let about = WindowType("notes.about")
}

struct NotesApp: Application {
    var body: some Scene {
        WindowGroup { NotesPage() }
        EditorScene()
        AboutScene()
    }
}

struct EditorScene: Scene {
    var body: some Scene {
        WindowGroup(.editor) { EditorPage() }
    }
}

struct AboutScene: Scene {
    var body: some Scene {
        Window(.about) { Text("Notes 1.0") }
    }
}

struct NotesPage: View {
    @Environment(\.application) private var application

    var body: some View {
        VStack {
            Button("New editor").onClicked(.ignoreWhileRunning) { try await application.openWindow(.editor) }
            Button("About").onClicked(.ignoreWhileRunning) { try await application.openWindow(.about) }
        }
    }
}

struct EditorPage: View {
    @Environment(\.window) private var window
    @Environment(\.scene) private var scene

    var body: some View {
        VStack {
            Button("Close").onClicked(.ignoreWhileRunning) { try await window.close() }
            Button("Close every editor").onClicked(.ignoreWhileRunning) { try await scene.close() }
        }
    }
}
```

- A window written in the application's body, like the `WindowGroup` here, is
  a scene of its own with no state.
- `application.openWindow(.editor)` opens one more editor window, in the scene
  declaring `.editor`, which opens with it where it does not stand.
- `application.openWindow(.about)` opens the About window once, and answers
  `WindowError.alreadyOpen` while it is open.
- `window.close()` closes one window, and the scene ends with its last;
  `scene.close()` closes every window of the scene at once.

`WindowType` names are durable application vocabulary. Use stable,
application-qualified names because restoration records them.

Every window carries the same four host metadata values. `windowType` is its
kind - none for a window of the `WindowGroup` with no name - and `windowValue`
the encoded per-value identity where the group has one. `hidesWhenInactive`
and `floatsOnTop` are always explicit booleans, so changing either policy
updates an existing native window without replacing it.

### Window policy

`hidesWhenInactive` and `floatsOnTop` describe how a group's windows stand
beside the application's other scenes:

```swift quote
Window(.inspector) { InspectorPage() }
    .hidesWhenInactive(true)
    .floatsOnTop(true)
```

Both default to `false` and are independent.

- `hidesWhenInactive(true)` hides each window of the group while another scene
  of the same application is in front, then shows it again with its own scene.
  It does not close the window or end its `WindowSession`.
- `floatsOnTop(true)` keeps the group's windows above the application's other
  windows while the application is in front. It does not make them global
  always-on-top windows.

Changing either policy updates windows that are already open. In particular,
turning `hidesWhenInactive` off while a window is hidden by its scene makes that window
visible again. Window lifecycle reports follow effective visibility: overlapping
scene and application hiding produces one `stopped`, and `resumed` arrives only
after neither cause keeps the window hidden.

Both policies are adaptive: a host implements them with its native window
relationships when that platform exposes the capability. A declaration is not
evidence that a particular host implements the policy; the
[platform matrix](../platform-contract.md#contract-members) is the
support authority.

## Application and scene phases

`ApplicationSession.phase` and `SceneSession.phase` use the same three words
at different ownership scopes:

| Phase | Application | Scene |
| --- | --- | --- |
| `.active` | one of the application's windows is in use | one of this scene's windows is in use |
| `.inactive` | application windows remain visible while another application is in front | this scene remains visible while another scene is in front |
| `.background` | none of the application's windows can be seen | every window of the scene is out of sight, or the application is hidden |

A multi-window application can therefore be `.active` while one of its scenes
is `.inactive`. `SceneSession.phase` starts at `.active` when a new scene is
being brought up and then follows reports for that scene. Neither value
replaces `WindowSession.phase`, which records the more detailed lifecycle of
one particular window.

The scene node has four host reports. `activated`, `deactivated`, and
`stopped` move `SceneSession.phase`. `windowClosed` - the user closed one of
the scene's windows - removes the window by the key the host supplies, and the
scene ends with its last. A tree-driven close emits no close report: the Swift
tree already owns that decision.

Lifecycle is an effective state, not a count of native callbacks. If a scene's
only window is minimized and the application is then hidden, showing the
application again does not resume either the window or its scene. They
advance only after the remaining minimized cause ends. The same rule prevents
duplicate phase changes when callbacks overlap.

## Scene-local restored state

`@State(sceneKey:)` is ordinary state whose storage belongs to the scene
standing: every window of the scene reads the one value. The host keeps it
with the scene's windows and hands it back before the restored scene is
described.

```swift quote
extension SceneKey {
    static let selectedDocument = SceneKey(
        "com.example.notes.selected-document",
        of: Int.self)
}

final class SelectionModel {
    @State(sceneKey: .selectedDocument) var document = 0
}
```

A scene stands once, so its key holds one value, which ends with the scene.
Process-wide preferences use `@State(persistentKey:)` instead; see
[State and reactivity](../concepts/state-and-reactivity.md).

## Opening and closing

The application opens a window by its kind; a session closes the exact
window or scene it is:

```swift quote
@Environment(\.application) private var application
@Environment(\.scene) private var scene
@Environment(\.window) private var window

try await application.openWindow()
try await application.openWindow(.inspector)
try await application.openWindow(.document, value: 7)
try await application.closeWindow(.document, value: 7)
try await window.close()
try await scene.close()
```

A window opens in the scene declaring its kind, which opens with it where it
does not stand. Whether a window may open beside another is the platform's: a
desktop and an iPad open one, a phone answers `.unsupported`.
`SceneSession.windows` and `ApplicationSession.scenes` are reactive readings.
A body that reads either is rebuilt when the collection changes.

Operations fail explicitly with `WindowError`: `.alreadyOpen`, `.notOpen`,
`.noScene`, `.undeclared`, `.wrongValue`, or `.unsupported`. A retained session
does not silently start referring to a newer scene after its own scene ends.

## Restoration

Restoration has two inputs with different owners:

- the platform keeps the windows that were open - AppKit and iPadOS by their
  own restoration, the other hosts in a store of their own - each with its
  kind, its value's text and its scene's `@State(sceneKey:)` values;
- StateUI brings each back as its kind for its value, in the scene declaring
  it, which opens with it and its kept values where it does not stand.

Restoration never changes the structural contract. A window kind must still be
declared, and its saved value must still decode as the group's declared type.
A record that no longer reads is refused rather than mapped onto another
window.

A restored scene's kept values land before its first build, so every window of
it starts from what the scene kept.

## Window session

`WindowSession` owns one running window's phase, title, geometry requests,
translucency, and `close()` operation. What the window shows - its pages, its
sheets, its bar - is the view its `WindowGroup` or `Window` shows.

| Member | Meaning |
| --- | --- |
| `phase` | the last lifecycle phase reported by the host |
| `title` | the name used by native window chrome and system window surfaces |
| `x`, `y` | optional top-left position of the outer frame in desktop coordinates |
| `width`, `height` | optional requested content-area size |
| `minimumWidth`, `minimumHeight` | optional lower content-size bounds |
| `maximumWidth`, `maximumHeight` | optional upper content-size bounds |
| `isMaximizable`, `isMinimizable` | whether the corresponding native operation is permitted |
| `background` | what the window is made of behind its pages: a colour, or a blur or glass the desktop shows through, where the platform can show it |
| `close()` | closes this exact window; its scene ends with its last |

Position and size are four independent optional requests:

```swift quote
@Environment(\.window) private var window

window.x = 120
window.y = 80
window.width = 900
window.height = 640
window.minimumWidth = 560
window.minimumHeight = 420
window.maximumWidth = 1600
window.maximumHeight = 1200
window.isMaximizable = true
window.isMinimizable = true
```

`width` and `height` describe the content area: what the window's title bar
and toolbar leave uncovered. A host whose content reaches under them, as
AppKit's does, sizes the window so that this area has the requested size, and
bounds it the same way. Changing one axis must not reapply a stale value for
another axis. `nil` leaves that axis under native
window ownership, including user resizing and platform restoration. Minimum
and maximum values constrain resizing; equal minimum and maximum values express
a fixed dimension. A minimum wins over a smaller maximum on the same axis.
A maximum bounds maximizing too: maximized, a window that has one grows to
that size at most - and on a Mac it takes no full screen - so a window meant
to fill a large screen sets none.
Clearing a constraint or operation preference restores the native value the
host found when it adopted the window. Full-screen hosts may retain geometry
requests without presenting movable or resizable window chrome.

`title` names the window where the page on show does not. A host whose window
chrome carries the visible page - AppKit's toolbar shows the visible page's
title, the way a Mac window is named after what it shows - names the window
after that page while it has a title, and after `title` otherwise; native
window menus, restoration surfaces, and accessibility follow the same name.
The name a window's bar declares for the application never names the window:
it describes only what the chrome shows ([The window's bar](#the-windows-bar)).

`isMaximizable` and `isMinimizable` govern the native operations, not merely
the appearance of one button. A host blocks equivalent native commands while
the corresponding value is `false`. `nil` preserves the platform's existing
capability.

`background` is what the window is made of behind its pages - around a
floating sidebar, under a page that paints no background of its own: a
colour, or a blur the desktop shows through, from `.ultraThin`, which lets the
most through, to `.ultraThick`, its tint lying over it. On AppKit the window's
own blur lies under the page, and the margin around a floating sidebar shows
it; on WinUI the desktop acrylic. It is a desktop semantic: a host whose
windows cannot show what is behind them paints the blur's colour instead.
Text belongs on a surface of its own rather than straight over the desktop.
`nil` keeps the platform's own window, and so does a nil half of a pair:

```swift quote
.onCreated {
    window.background = .blur(.thick.tint(Color("#26512BD4")))
}
```

```swift quote
.onCreated {
    // The platform's own window in the light theme, a tinted blur in the dark.
    window.background = Material(light: nil, dark: .blur(.thick.tint(Color("#26512BD4"))))
}
```

The host reports `WindowPhase` through the same session:

| Phase | Meaning |
| --- | --- |
| `.created` | the initial state; the native window now exists |
| `.activated` | the window is in front and receiving input |
| `.deactivated` | it remains visible but another window or application is in use |
| `.stopped` | it cannot be seen because it is minimized, hidden with its scene, or its application is hidden; save work here |
| `.resumed` | it has returned from `.stopped` and is moving toward activation |
| `.destroying` | the final notification before the window goes away |

The exact path is platform-adaptive: a host reports only transitions that
occur in its lifecycle. Each phase it reports is rendered before its next
report, so `.onChanged(window.phase)` sees every one. Repeating the phase
already stored changes no state, and therefore triggers no extra reaction.

```swift quote
.onChanged(window.phase, .waitForPrevious) { oldPhase, newPhase in
    if newPhase == .stopped {
        try await saveDraft()
    }
}
```

## What a view says of its page

Whatever a container shows as a screen - a window's view, a navigation stack's
root and destinations, a tab, either half of a split view, a sheet - stands on
a page. Nobody declares one: the container puts the view on a page, kept for
as long as the same view stands there - the same view type under the same
explicit id. Another view in that place stands on a page of its own.

What the page is, the view it shows says by modifier:

| Modifier | Meaning |
| --- | --- |
| `.title` | navigation title, and the caption where the page is an item of something else |
| `.icon` | the page's representative image, commonly a tab icon |
| `.pageBackground` | flat color behind the whole page, also where the view does not reach |
| `.showsNavigationBar` | whether a containing navigation stack shows its bar for this page |
| `.showsBackButton` | whether that bar offers its native back affordance |
| `.backButtonTitle` | short title supplied by this page for the page pushed above it |

What is not said is left with the host. Each takes a value, and each but
`.icon` a state, `$x`, which the host follows with no view built again. The space between the page's
edge and what it shows is that view's own `.padding`. These are said of the
page only by the view it shows - or by that view's `body` - and a view further
in that says them says nothing, and is told so once.

An arrangement - `NavigationStack`, `TabView`, `SplitView`, `ModalStack` - is
a view that stands where a page stands, as the page itself: written there, or
the `body` of the view written there. Anywhere else - inside a `VStack`, inside
a page's content - it is left out and said once. It fills where it stands, so
it keeps only what its contract declares, and takes its own `.title` and
`.icon`, for where it is an item of something else, such as a tab.

What has a body of its own - the page's actions, the view in its title's place
and its menus - is declared in the view as well, with `.toolbar { }`,
`.titleView { }` and `.menuBar { }`, and built with the state it follows (see
[Navigation and presentation](navigation-and-presentation.md#toolbars)). So is
what the page lays over its window, with `.overlays { }`: declared on a
window's page it stands over every page and sheet the window shows, declared on
a page further in it stands while that page is shown
([Over every page](navigation-and-presentation.md#over-every-page)).

The back-button title belongs to the page being returned to, not the page
currently on top. Hiding the native back button hides that affordance; it is
not a cross-platform navigation lock. Title views, toolbar
items, and menu items are ordinary identified subtrees built where their
native surface presents them. Modal presentation is adaptive: each host uses
its platform's native presentation for the pages a `ModalStack` presents
([modal pages](navigation-and-presentation.md#modal-pages)).

Page content remains compositional. An image behind content is an `Image` in
the page tree, safe-area participation is a layout property, and input is
released explicitly with `Aim.unfocus()` or `OnScreenKeyboard.hide()`. A custom title,
including an image, belongs in `.titleView { }`; bar foreground color
belongs to the containing page arrangement.

A value the body computes is said again whenever the body is built again:

```swift quote
struct EditorPage: View {
    @State private var dirty = false

    var body: some View {
        TextEditor()
            .toolbar {
                ToolbarItem("Save")
                    .isEnabled(dirty)
                    .onClicked { save() }
            }
            .title(dirty ? "Draft - Edited" : "Draft")
    }
}
```

The page hears its phases through handlers, one per phase, which separate
general visibility from navigation-specific movement:

| Modifier | Runs |
| --- | --- |
| `.onAppearing` | as the page is about to become visible, including a return or tab selection |
| `.onNavigatedTo` | once a navigation move has arrived at it |
| `.onNavigatingFrom` | as a navigation move is about to leave it |
| `.onDisappearing` | as it is covered or left, including a tab selection change |
| `.onNavigatedFrom` | once the navigation move away from it has completed |

A navigation arrival runs `.onAppearing` and then `.onNavigatedTo`. A
navigation departure runs `.onNavigatingFrom`, `.onDisappearing`, and then
`.onNavigatedFrom`; a tab switch needs only disappearance and appearance. A
host does not invent navigation phases for a visibility change that was not a
navigation move, and a page whose view hears no phase is told none.

`onCreated` and `onDestroying` describe the lifetime of a StateUI element;
they are not substitutes for page appearance or window activation. Use the
session phase whose scope matches the work.

## The window's bar

The window's bar is declared on the arrangement the window's view is, as values
read in the body - so it follows the state it reads with no write of its own:

```swift
import StateUI

struct NotesPage: View {
    @State private var showsFolders = true
    @State private var folder = "Personal"
    @State private var query = ""

    var body: some View {
        SplitView($showsFolders) {
            Text("Folders")
        } detail: {
            Text("Notes in \(folder)")
        }
        .barTitle("Notes")
        .barSubtitle(folder)
        .barIcon("notes.png")
        .barBackgroundColor(.cornflowerBlue)
        .barForegroundColor(.white)
        .titleView {
            SearchField($query)
        }
        .toolbar(.leading) {
            ToolbarItem("New folder")
        }
        .toolbar {
            ToolbarItem("Account")
        }
    }
}
```

`barTitle`, `barSubtitle` and `barIcon` are the application naming itself, the
line under the title, and its mark; `barBackgroundColor` and
`barForegroundColor` paint the bar and what stands on it. Each is taken from
the nearest arrangement on the visible path that declares it, so a stack
further in paints its own bar or says its own line while it is shown; a
sidebar and a sheet take nothing from around them. What stands on the bar is
declared the same way: actions with `.toolbar`, `.toolbar(.leading)` at the
leading edge, and a view in the title's place with `.titleView`
([Toolbars](navigation-and-presentation.md#toolbars)).

A desktop host shows the name, the line and the mark where its platform names
the application - AppKit as text at the trailing edge of the title bar, WinUI
in its title bar's title, subtitle and icon - while the visible page's title
still names the window to the system. On a phone and a tablet each bar names
its page: the line stands under each page's title, and the application's name
and mark stand nowhere. [BarElement](../controls/tiers/BarElement.md) lists
each value, and the page of each arrangement wearing it says what each host
does with it.

## Reading support status

The types above define StateUI's cross-platform vocabulary. They do not make a
blanket implementation claim. The platform matrix deliberately verifies these
groups separately:

- application, scene, window ownership and restoration;
- window lifecycle handlers;
- window geometry and native operations;
- auxiliary-window metadata and policies;
- core page properties and lifecycle;
- adaptive page properties and structural slots;
- the bar an arrangement declares.

A `✅` covers the complete member group in its row. A blank cell means absent,
partial, or unverified support, even when a related row for the same session is
checked. This prevents a working lifecycle from being mistaken for working
geometry, chrome, or presentation policy.

Current native evidence for sessions, lifecycle, geometry, and restoration is
tracked in [Platform contract](../platform-contract.md).
