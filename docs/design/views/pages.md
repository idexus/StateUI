# Pages and windows

An application declares its structure as types and builders. An
`Application`'s body is its scene, a `Scene`'s body its windows - a
`WindowGroup` and the windows beside it - and each window shows a view, which
stands on a page. Each declares only what it is made of; what the application,
a scene and a window are while they run lives in their sessions, and what a
page is, its view says.

## Application scene window page

```text
  Application ──body──▶ Scene ──body──▶ WindowGroup ──▶ view ──▶ page ──▶ view tree
                                   └──▶ Window, WindowGroup(for:) ──▶ view

  ApplicationSession    SceneSession        WindowSession             said by its view
  styles, motion,       closes, with        title, frame,             title, background,
  kept values, opens    its windows         lifecycle                 bar requests, phases
  windows
```

`Application` and `Scene` are protocols with one composition getter each,
`body`, built by `ApplicationBuilder` and `SceneBuilder`. A window shows a
view: an arrangement stands there as the page itself, any other view on a page
element around it. The sessions are objects in the environment of everything
under them, written like any state, and a page is what its view says of it by
modifier, so the tree is steered by `@State` and `@Environment` alone.

## Scenes

A scene is a set of windows and the state they share. An application declares
its scenes, each standing at most once: it opens with its first window -
launch opens the window of the `WindowGroup` with no name, *File ▸ New* one
more, `openWindow` one of a kind - and ends with its last
([scenes.md](../core/scenes.md#a-scene-stands-once)).

```text
  struct GalleryApp: Application {
      @State private var library = Library()                  every scene's
      var body: some Scene {
          GalleryScene().environment(library)
          Window(.about) { AboutPage() }                      a scene of its own
      }
  }

  struct GalleryScene: Scene {
      @State private var theme = Theme()                      the scene's
      var body: some Scene {
          WindowGroup { MainPage() }.environment(theme)       launch, New: one more
          Window(.fonts) { FontsPanel() }.environment(theme)  one
          WindowGroup(.document, for: UUID.self) { $id in DocumentPage(id: id) }
      }
  }
```

- A scene's state is its type's own `@State`, and every window of it reads
  it, offered with `.environment` or handed in as a binding. What belongs to
  one window is the `@State` of the view it shows.
- A scene's body takes windows in any number and order (`SceneBuilder`), and
  refuses a view or another scene; an application's body takes scenes
  (`ApplicationBuilder`), a window written there being a scene of its own,
  and refuses a view. A refused expression meets an unavailable
  `buildExpression` of its own, one no available generic overload also
  matches: beside such an overload it would lose, as the type checker
  penalizes what is unavailable.
- An object is offered to a window by `.environment(_:)` on its `WindowGroup`
  or `Window`, and to every window of a scene by `.environment(_:)` on the
  scene where the application names it.
- A window of a kind opens through the application's session,
  `application.openWindow(.fonts)`, in the scene declaring the kind. It may
  hide while another scene is in front, and closes with its scene.
- What the system restores is what was open: each window comes back as its
  kind for its value, and its scene with the values its `@State(sceneKey:)`
  held. A group's value is `Codable` for that reason, and a `WindowType` name
  is written down with every window, so it should not change between
  versions.

Which scenes stand is the library's to hold (`OpenScenes.swift`), never the
author's. A host maps windows onto the window or scene identities its
platform provides; a platform that shows one window refuses another with
`WindowError.unsupported`.

## A window is a placeholder

A window's node is a placeholder like a composed view's (`Node.window`), so it
is built again on its own when what it reads moves; the view it shows holds the
state. Its `WindowSession` is handed to it by its scene, which keeps it.

The session and the place its scene's inspector docks in, where it docks in
this window, are asked for inside the window's build, so the window is what
builds again when either moves. The session is also offered on the
placeholder itself, so the window's own `@Environment` resolves it as well as
everything under it.

## The children of a window

A window node's children are its page, then the library's own overlay.
The host finds them by type, so the order is this side's to settle, and one
order makes the window's children the same list in every run.

```text
  Window
   ├── ModalStack    the window's page, here a modal stack
   │    ├── Page         what it holds
   │    └── Page …       its sheets, the last on top
   └── Overlay       the library's: a docked inspector's panel
        └── ZStack       lets a click beside it through
```

What a page lays over the window is declared on it (`.overlays { }`): an
overlay node after the declaring element's own children, holding one ZStack
of the views, so a view coming or going leaves the others the elements they
were. The host lays the overlays of the path it shows - the outer under the
inner - and the library's own over them all
([the overlays of a window](../host/pages.md#the-overlays-of-a-window)). The
inspector docks by a value of its scene (`dockedInspector`), whose panel the
window it docks in lays as it builds.

## Lifecycle reports one by one

A window and a page hear where they stand in their life - created, activated,
appearing, navigated to - through one handler written per report. The
handlers are written out one by one rather than iterated over a collection:
the patch is deterministic, and a dictionary or a set iterated into a message
can differ between two instances within one run.

## A page around a view

A view shown as a screen gets a page element around it (`Node.page`). The page
is kept while the same view stands there - the same kind under the same
explicit id, from the same branch - and made afresh for another. A page position takes its view through `ViewBuilder`,
so an `if`/`else` or a `switch` there keys each branch (`Either`), and two
branches of the same view are two pages, as two branches in a container are
two elements.
The view stays the element it is, one level down, with its state, its inputs
and whatever was written on it.

The view is the page's one child. What it declares for the page's chrome - a
title view, a toolbar, menus, overlays - are slot children after the view's
own (modifiers.md, slot children), so gaining one moves nothing. The view is
held as a node - interface, not an input anything compares - so the page is
built with its parent and the view is compared on its own.

## What a view says of its page

What a screen is - its title and icon, its background, whether the navigation
bar and the way back show, the back button's words, the phases it hears - is
said by modifiers on the view a page shows: `.title`, `.icon`,
`.pageBackground`, `.showsNavigationBar`, `.showsBackButton`,
`.backButtonTitle`, `.onAppearing`, `.onDisappearing`, `.onNavigatedTo`,
`.onNavigatingFrom`, `.onNavigatedFrom`. Each takes a value, and a value one
takes from a state, `$x`, is a channel the host follows without a view being
built again.

They are held apart from the view's own values (`PageValues`, `pageSays`): the
page's background never meets the view's `.background`, and the page has no
padding of its own - the view's `.padding` is the space inside it. Written on a
composed view, they stand over what its `body` says, as any modifier written on
a view stands over its body (`Stateful.expand(over:)`).

The differ describes a page's view before the page itself and the page takes
what the view said: its values, its channels and its handlers. The page takes
the view's reads too, so a write to a state the values read describes the page
again although the page itself read nothing. A page carries only the phases its
view hears; a host raises a phase for which the page carries a handler.

The place decides, not the type, since any view may stand on a page. An
arrangement standing where a page stands is the page, and takes the title and
the icon itself, for where it is shown as an item of something else, such as a
tab; anything else said of a page there is said once (`complain`) and left out.
Written on a view no page shows - inside a layout, deeper in a body - what a
view says of its page says nothing, and is said once.

## An arrangement is a view

`NavigationStack`, `TabView`, `SplitView` and `ModalStack` are views
(`ElementView`), so a view's `body` may be one. An arrangement stands where a
page stands - a window's view, a page of another arrangement - as the page
itself, with no page element around it. Whether a view builds one is told by
its type (`Node.isArrangement`): an arrangement, or a composed view whose
`body`, followed down, ends on one; the placeholder records the view's type,
so a modifier written on the view keeps the answer. A `body` whose `if`
chooses between an arrangement and another view cannot be told by its type,
and stands as a view.

Anywhere else an arrangement is left out of what is described and said once
(`complain`): inside a layout, and inside a page, where a view's branch chose
one. No type refuses an arrangement in a `VStack`, since a composed view may
hide one in its `body`; the hosts show one only where a page stands. An
arrangement fills where it stands, so it keeps what its contract declares - its
bar, its title and icon, its own state - and leaves out, said once, what a
view's modifier writes on it: a width, a margin, a gesture.

What a screen is - its title, its buttons - its view says of its page. An
arrangement's bar belongs to the arrangement (`BarElement`) and looks the same
whichever page it shows. An arrangement standing where a page stands takes its
own title and icon from the same modifiers, for where it is shown as an item
of something else, such as a tab.

## The stack is the state

What is on the native navigation stack is an array the author holds, of the
author's own type. Push is `path.append(_:)`, pop is `path.removeLast()`, back
to the root is `path = []`. There is no navigate call, no route string and no
registry: the stack is the state, so every question about where the
application is has an answer that can be read, tested and serialized on this
side. The host reconciles its native navigation to the described stack.

The destination closure is a `switch` over the author's own type, so the
compiler checks that every route has a page; a misspelled route string would
be a fault the user finds. The root page usually takes the binding: a page that
pushes has to be able to write the path, and `HomePage()` handed nothing
compiles and then cannot navigate.

A model may hold the path - `router.$path` is the path's own state - and be
offered to every page with `.environment(_:)`, naming the moves itself. The
library ships no router: its names would be the library's, and the array is
the whole mechanism.

## An arrangement keys its pages

A page in an arrangement is keyed by the arrangement, never by the author. The
key is what pairs a report with the page it is about, so it belongs to the
mechanism; an `.id()` written on the view stays on the view the page shows.

```text
  NavigationStack   the root              "root"
                    a pushed page         "<depth>/<route>"
  ModalStack        the root              "root"
                    a presented page      "<depth>/<sheet>"
  TabView           a tab's page          "<tab>"
  SplitView         the two pages         "sidebar", "detail"
```

On a stack neither half of the key is enough. Depth alone would hand the page
at index 1, and the `@State` in it, to whatever route replaced it after a pop
and a push. The route alone cannot tell two `.level(2)` pages apart, which a
stack may hold. A route always carries its depth, so no route's key can equal
the root's.

Tabs are keyed by value alone. A tab bar holding one tab twice is a mistake,
and keying by value lets the tabs be reordered without their pages being
rebuilt.

Routes, sheets and tabs are described into text, the way `ForEach` keys are
(builders.md, ForEach keys are text), so distinct values must describe
differently and a class does not qualify.

## A pop report only shortens

The platform's own way back - the arrow, the swipe, the system back gesture -
reports only once it has committed: an interactive swipe let go halfway pops
nothing and says nothing. The payload is how deep the stack now is, above the
root, and the path is truncated to match; the next render finds the native
stack already in the described state and does nothing. A modal that goes
without this side saying so - an interactive dismissal, a native back action,
the platform closing one because the page under it went - reports how many
remain, the same way.

The guard only ever shortens. A report as deep as the path already is, or
deeper, has been overtaken by another pop and would otherwise put pages back.
A report overtaken by a push is not recognized and truncates the path: a narrow
race - the user's back press has to land between a handler queuing a push and
that push being described - which resolves the way the user's finger said.
Recognizing it would take numbered reports, a moving part the stack does not
carry.

## Tabs report an index

Which tabs there are is a collection the author holds, of the author's own
type; which one shows is a binding of that same type. A collection rather than
a builder of pages is what makes the keys work: a tab is a value, so the page
for it can be keyed by it. The tabs are held as `AnyHashable`, since a
`TabView` is not generic, and opened again in `selection`, whose binding
says which type to expect.

The selection crosses as the index of the current page among the children -
the list the initializer described, so the two cannot mean different things. A
binding that names no tab says nothing, which is not an error: the platform
shows something, reports which, and the binding is written to match. That is
also how removing the selected tab resolves itself, with no rule of its own.

The user's choice arrives as an index into that list and is written only when
it moved: a binding written with the value it already holds would be a render
nobody asked for. The host guards the same from its side, and the pair keeps a
tab switch to exactly one render. A binding of a type the tabs are not names
nothing rather than trapping.

## Split view

A split view is two pages: a sidebar beside the page the user is looking at.
Whether the sidebar shows is a `Bool` the author holds, borrowed two-way.

The sidebar is an ordinary page. Its rows are whatever views the author writes,
a row is a button whose handler assigns state, and no item type, template or
selection of its own is the library's business. The platform's ways in and
out - its sidebar button, an edge swipe, a tap on the dimmed page - report only
once the gesture has finished, whatever it settled on, and are written only
when the value moved.

## The modal stack is the state

What is presented over a window is a stack of the author's own values, the
last on top: presenting is `sheets.append(.settings)`, closing is
`sheets.removeLast()`, closing everything is `sheets = []`. There is no present
call and no completion to await. It is a stack because the platforms make it
one: a sheet may present a sheet.

`ModalStack` is an arrangement of `NavigationStack`'s shape, standing as a
window's page: the page it holds first, the sheets after it, each built as
the arrangement builds from the array as it stands then, so what builds the
arrangement is what builds again when the array moves. A sheet's identity
carries its depth and its value, as a stack's page does. The report that a
sheet has gone is the stack's own (`popped`), with how many remain.

## What an arrangement does not offer

- No current page value: the bound path, selection or flag already says where
  the application is, before the host draws anything.
- No push, pop, present or select act: assigning the state is navigation.
- No separate push and pop notifications: the state is the one channel, and
  `.onChanged(path)` observes every committed arrival and departure.
- No page look on a stack: a `NavigationStack` draws its bar and the page on
  top; that page carries its own background and safe-area inset, and its view
  its own padding.
- No builder of tab pages: a builder hands back an anonymous list whose only
  identity is position.
- No sidebar item type, template, header or footer: the sidebar is a page, and
  a header is a view at its top. No way to keep a split view with its sidebar
  turned off for good: an application with nothing for a sidebar does not use
  one. No shared overlay or split policy: that belongs to a platform's own
  container, and the host adapts its presentation.

## The application is named once

`stateUIUseApp` is the one line an application writes outside its interface,
in `stateui_app_register()`, a `@_cdecl` function in the application's own
module. Each platform's head calls it at startup: its `main.swift`, or on
Android `JNI_OnLoad`, which Android calls by name as it loads the
application's library.

The application is made at its first need - the first render, or the host
reading the keys it keeps - after anything an earlier one wrote into the
application's session has been forgotten, so its `init` starts from nothing.
It is kept for the life of the process, so `@State` declared on it is the
state that outlives every window. Its `init` is where the kept state's keys
are written: the host reads them before the first view is built.
