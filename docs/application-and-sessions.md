# Applications and sessions

StateUI separates structural declarations from the identity-bearing objects
that exist while an application runs:

```text
declaration         runtime state
-----------         ------------------
Application         ApplicationSession
Scene               SceneSession
Window              WindowSession
Page                PageSession
```

A declaration answers what it is composed of. Its session answers what the
particular running instance is called, where it stands in its lifecycle, and
what actions can be taken on it. Sessions are ordinary objects with `@State`
properties and are resolved through `@Environment`.

## Application

An application declares one scene shape. A window itself conforms to `Scene`,
so a single-window application needs no extra scene type:

```swift
struct SingleWindowApp: Application {
    var scene: any Scene { MainWindow() }
}

struct MainWindow: Window {
    var page: any Page { HomePage() }
}

struct HomePage: ContentView {
    var content: any View { Label("Home") }
}
```

`ApplicationSession` owns process-wide policy and reports process-wide state:

| Member | Meaning |
| --- | --- |
| `phase` | active, inactive, or background |
| `scenes` | currently open scene sessions, in opening order |
| `styles` | the application's `StyleSheet` |
| `motion` | default motion law |
| `persistentKeys` | state keys hydrated before the first description |
| `persistentStorage` | the selected host storage |
| `openScene()` | asks for another independent scene session |

Configuration needed before the first view is built belongs in the
application's initializer:

```swift quote
struct NotesApp: Application {
    @Environment private var application: ApplicationSession

    init() {
        application.styles = AppStyles.sheet
        application.motion = .spring(response: 300)
        application.persistentKeys = [.lastDocument]
    }

    var scene: any Scene { NotesScene() }
}
```

## Scene ownership

A scene is one independent application session: its main window, any auxiliary
windows opened beside it, and the state those windows share. A platform may
restore several instances of the same scene declaration. Each instance gets a
different `SceneSession` and different scene-owned state.

Use a dedicated scene type when there is shared session state or more than one
window kind:

```swift quote
extension WindowType {
    static let inspector = WindowType("notes.inspector")
    static let document = WindowType("notes.document")
}

struct NotesScene: Scene {
    @State private var selection = SelectionModel()

    var windows: Windows {
        Windows {
            WindowGroup(.inspector) { InspectorWindow() }
            WindowGroup(.document, for: Int.self) { number in
                DocumentWindow(number: number)
            }
        } main: {
            MainWindow()
        }
        .environment(selection)
    }
}
```

The `main` window is the scene's lifetime boundary. Closing it closes the scene
and every window belonging to it. A `WindowGroup` declares a kind the scene is
allowed to open:

- `WindowGroup(.inspector) { ... }` allows one window of that kind per scene;
- `WindowGroup(.document, for: ID.self) { $id in ... }` allows one per value;
- the value is `Codable` and `Hashable` so it can identify and restore the
  window;
- the value closure receives a `Binding`, so the same window can be retargeted
  without replacing its session.

`WindowType` names are durable application vocabulary. Use stable,
application-qualified names because restoration records them.

Every owned window carries the same four host metadata values. `windowType`
is the group's open and restoration identity; `windowValue` is the encoded
per-value identity when the group has one. `autoHide` and `floatsOnTop` are
always explicit booleans, so changing either policy updates an existing native
window without replacing it. The main window carries none of this group
metadata.

### Auxiliary-window policy

`autoHide` and `floatsOnTop` describe auxiliary windows, not new scenes:

```swift quote
WindowGroup(.inspector) { InspectorWindow() }
    .autoHide(true)
    .floatsOnTop(true)
```

Both default to `false` and are independent.

- `autoHide(true)` hides each window of the group while another scene of the
  same application is in front, then shows it again with its owning scene. It
  does not close the window or end its `WindowSession`.
- `floatsOnTop(true)` keeps the group's windows above the application's normal
  windows while the application is in front. It does not make them global
  always-on-top windows, and it does not change their scene ownership.
- Auxiliary windows belong to their scene and close with it. System surfaces
  that enumerate application documents or main windows should enumerate scene
  main windows, not these helpers.

Changing either policy updates windows that are already open. In particular,
turning `autoHide` off while a window is hidden by its scene makes that window
visible again. Window lifecycle reports follow effective visibility: overlapping
scene and application hiding produces one `stopped`, and `resumed` arrives only
after neither cause keeps the window hidden.

Both policies are adaptive: a host implements them with its native window
relationships when that platform exposes the capability. A declaration is not
evidence that a particular host implements the policy; the
[platform matrix](platform-contract.md#control-properties-and-handlers) is the
support authority.

## Application and scene phases

`ApplicationSession.phase` and `SceneSession.phase` use the same three words
at different ownership scopes:

| Phase | Application | Scene |
| --- | --- | --- |
| `.active` | one of the application's windows is in use | one of this scene's windows is in use |
| `.inactive` | application windows remain visible while another application is in front | this scene remains visible while another scene is in front |
| `.background` | none of the application's windows can be seen | the scene's main window is stopped, or the application is hidden |

A multi-window application can therefore be `.active` while one of its scenes
is `.inactive`. `SceneSession.phase` starts at `.active` when a new scene is
being brought up and then follows reports for that scene. Neither value
replaces `WindowSession.phase`, which records the more detailed lifecycle of
one particular window.

The scene node has six host reports. `activated`, `deactivated`, and `stopped`
move `SceneSession.phase`. `destroying` ends the scene after its main window is
closed. `windowClosed` removes the exact owned-window key supplied by the host,
while `windowRestored` offers a restored kind and optional encoded value back
to that scene. A tree-driven close emits neither close report: the Swift tree
already owns that decision.

Lifecycle is an effective state, not a count of native callbacks. If the main
window is minimized and the application is then hidden, showing the
application again does not resume either the main window or its scene. They
advance only after the remaining minimized cause ends. The same rule prevents
duplicate phase changes when callbacks overlap.

## Scene-local restored state

`@State(sceneKey:)` is ordinary state whose storage belongs to the current
scene session. The host serializes it with that scene and hydrates it before
the restored scene is described.

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

Two scenes using the same key do not share one value. Each scene restores its
own. Process-wide preferences use `@State(persistentKey:)` instead; see
[State and reactivity](state-and-reactivity.md).

## Opening and closing

Session methods act on the exact session object held by the view:

```swift quote
@Environment private var application: ApplicationSession
@Environment private var scene: SceneSession
@Environment private var window: WindowSession

try await application.openScene()
try await scene.openWindow(.inspector)
try await scene.openWindow(.document, value: 7)
try await scene.closeWindow(.document, value: 7)
try await window.close()
try await scene.close()
```

`SceneSession.windows` and `ApplicationSession.scenes` are reactive readings.
A body that reads either is rebuilt when the collection changes.

Operations fail explicitly with `WindowError`: `.alreadyOpen`, `.notOpen`,
`.noScene`, `.undeclared`, `.wrongValue`, or `.unsupported`. A retained session
does not silently start referring to a newer scene after its own scene ends.

## Restoration

Restoration has two inputs with different owners:

- the platform reconnects scene and native-window identities that were open;
- StateUI restores declared window kinds, per-value identities, and
  `@State(sceneKey:)` values into the matching scene session.

Restoration never changes the structural contract. A window kind must still be
declared by the scene, and its saved value must still decode as the group's
declared type. Unsupported or obsolete records are refused rather than mapped
onto another window.

The scene declaration is rebuilt before its restored group windows are
materialized, so every restored window receives the same session environment
as a newly opened one.

## Window session

`WindowSession` owns one running window's phase, title, geometry requests,
authored title area, modal stack, and `close()` operation.

| Member | Meaning |
| --- | --- |
| `phase` | the last lifecycle phase reported by the host |
| `title` | the name used by native window chrome and system window surfaces |
| `x`, `y` | optional top-left position of the outer frame in desktop coordinates |
| `width`, `height` | optional requested content-area size |
| `minimumWidth`, `minimumHeight` | optional lower content-size bounds |
| `maximumWidth`, `maximumHeight` | optional upper content-size bounds |
| `isMaximizable`, `isMinimizable` | whether the corresponding native operation is permitted |
| `titleBar` | optional authored title-area content |
| `modalStack` | pages presented over this window, with the last one on top |
| `close()` | closes this exact window; closing the main window ends its scene |

Position and size are four independent optional requests:

```swift quote
@Environment private var window: WindowSession

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
window ownership, including reader resizing and platform restoration. Minimum
and maximum values constrain resizing; equal minimum and maximum values express
a fixed dimension. A minimum wins over a smaller maximum on the same axis.
Clearing a constraint or operation preference restores the native value the
host found when it adopted the window. Full-screen hosts may retain geometry
requests without presenting movable or resizable window chrome.

`title` names the window where the page on show does not. A host whose window
chrome carries the visible page - AppKit's toolbar shows the visible page's
title, the way a Mac window is named after what it shows - names the window
after that page while it has a title, and after `title` otherwise; native
window menus, restoration surfaces, and accessibility follow the same name. A
`titleBar`'s own title never names the window: it and the interactive slots
describe only that visible area.

`isMaximizable` and `isMinimizable` govern the native operations, not merely
the appearance of one button. A host blocks equivalent native commands while
the corresponding value is `false`. `nil` preserves the platform's existing
capability.

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
.onChanged(window.phase) { oldPhase, newPhase in
    if newPhase == .stopped {
        try await saveDraft()
    }
}
```

## Page session

Whatever a container shows as a screen - a window's `page`, a navigation
stack's root and destinations, a tab, either half of a split view, a sheet -
is a `Page`. Nobody declares one by hand: every view is a page, usually a
`ContentView` of the application's own, and so is each arrangement. The
container puts a view on a page that owns one `PageSession` for as long as
the same view stands on it: the same view type under the same explicit id.
Another view in that place starts a session of its own. A write to the session
builds the page again and carries the view on it whole. An arrangement -
`NavigationStack`, `TabbedView`, `SplitView` - is a page already and is shown
as it is; it is not a view, so it stands only where a page stands, and it is
told what it is by modifier.

| Member | Meaning |
| --- | --- |
| `phase` | the page's current visibility or navigation phase |
| `title` | navigation title and the caption when the page is used as an item |
| `iconImageSource` | the page's representative image, commonly a tab icon |
| `padding` | space between the page edge and its content |
| `background` | flat color behind the page |
| `hasNavigationBar` | whether a containing navigation stack shows its bar for this page |
| `hasBackButton` | whether that bar offers its native back affordance |
| `backButtonTitle` | short title supplied by this page for the page pushed above it |
| `titleView` | an authored view replacing the navigation title |
| `toolbarItems` | actions in the page toolbar |
| `menuBar` | menus active while the page is visible on a platform with a menu bar |

Every optional value starts as `nil`, which leaves that choice with the host.
The toolbar and menu collections start empty.

The back-button title belongs to the page being returned to, not the page
currently on top. Hiding the native back button hides that affordance; it is
not a cross-platform navigation lock. `titleView`, toolbar
items, and menu items are ordinary identified subtrees built where their
native surface presents them. Modal presentation is adaptive: each host uses
its platform's native presentation for pages in `WindowSession.modalStack`.

Page content remains compositional. An image behind content is an `Image` in
the page tree, safe-area participation is a layout property, and input is
released explicitly with `Aim.unfocus()` or `SoftInput.hide()`. A custom title,
including an image, belongs in `titleView`; bar foreground color
belongs to the containing page arrangement.

Set stable page furniture when the content element is created and update it
when the state it depends on changes:

```swift quote
struct EditorPage: ContentView {
    @Environment private var page: PageSession
    @State private var dirty = false

    var content: any View {
        TextEditor()
            .onCreated {
                page.title = "Draft"
                page.toolbarItems = [saveItem]
            }
            .onChanged(dirty) {
                page.title = dirty ? "Draft - Edited" : "Draft"
            }
    }
}
```

`PagePhase` separates general visibility from navigation-specific movement:

| Phase | Meaning |
| --- | --- |
| `.created` | the page has been described but has not yet appeared |
| `.appearing` | it is about to become visible, including a return or tab selection |
| `.navigatedTo` | a navigation move has arrived at it |
| `.navigatingFrom` | a navigation move is about to leave it |
| `.disappearing` | it has been covered or left, including a tab selection change |
| `.navigatedFrom` | the navigation move away from it has completed |

A navigation arrival normally reports `.appearing` and then `.navigatedTo`.
A navigation departure reports `.navigatingFrom`, `.disappearing`, and then
`.navigatedFrom`; a tab switch needs only disappearance and appearance. Each
phase is rendered before the next report, so `.onChanged(page.phase)` sees
every one - an arrival's `.appearing` as well as its `.navigatedTo`. A host
does not invent navigation phases for a visibility change that was not a
navigation move. As with windows, a duplicate report of the standing phase is
a no-op.

`onCreated` and `onDestroying` describe the lifetime of a StateUI element;
they are not substitutes for page appearance or window activation. Use the
session phase whose scope matches the work.

## Authored title areas

`WindowSession.title` is the native window name. `TitleBar` is a
separate, adaptive view for a host that supports an authored title area:

```swift quote
window.titleBar = TitleBar("Notes")
    .subtitle("Personal")
    .icon("notes.png")
    .foregroundColor(.white)
    .leadingContent { Button("Sidebar") }
    .content { SearchField($query) }
    .trailingContent { Button("Account") }
    .background(.cornflowerBlue)
```

The initializer supplies the title. `subtitle`, `icon`, and
`foregroundColor` supply title-area values; ordinary view modifiers such as
`background` style the bar itself. The leading, center, and trailing
closures are identified child subtrees, so controls in them keep ordinary
state, events, and identity. Returning no child removes that slot; use a
layout inside a slot when it contains several controls.

The AppKit host puts the slots in the window's one native `NSToolbar`, beside
the visible page's own furniture: the leading and trailing content as toolbar
items and the content in the centre. The title, subtitle and icon stand as
text at the trailing edge of the title bar. AppKit owns placement, window
dragging, overflow and the toolbar's material, so the title area's colours are
the system's; the slot items keep the same StateUI-created native views across
updates.

Set the title bar through the window session. A platform without an authored
native title area may ignore it; the
[TitleBar matrix row](platform-contract.md#control-properties-and-handlers)
must carry a check before an application relies on it.

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
- authored `TitleBar` properties and slots.

A `✅` covers the complete member group in its row. A blank cell means absent,
partial, or unverified support, even when a related row for the same session is
checked. This prevents a working lifecycle from being mistaken for working
geometry, chrome, or presentation policy.

Current native evidence for sessions, lifecycle, geometry, and restoration is
tracked in [Platform contract](platform-contract.md).
