# GTK host

The GTK host renders a StateUI application with GTK 4 and libadwaita on
Linux. It is Swift, in the application's own process, beside the application
module and the library: it applies the typed sparse patches of the
[host contract](../internals/host-contract.md) directly and calls GTK and libadwaita
through their C API, with nothing beneath it in another language.

It presents StateUI's controls, arrangements and pages over the runtime every
host shares - the [platform contract](../platform-contract.md#control-creation) says
which, member by member. Each page stands under a header bar of its own that
slides with it, a sidebar beside the detail or over it in a narrow window,
tabs chosen by a switcher in the header bar, as GNOME's applications stand.
Opacity, sizes and transforms animate, a turn in depth included, a stack's
children travel to their new places, and a child the tree hides fades out
first. A layout paints its own box and cuts what it holds to it. It shows any
other control's name in red where the control belongs, so a gap is visible
rather than silent. It looks as the desktop's own applications do:
libadwaita's widgets, and the light or dark style the desktop is set to.

```text
lib/StateUI/StateUI.GTK/
  Sources/StateUIGTK/        the host: its runtime, elements, registrations, layout and window
  Sources/CStateUIGTK/       GTK's and libadwaita's headers, found by pkg-config
  Testing/                   a package of its own: the host's suite, run by swift test, in Tests/,
                             and the driver every conformance run on GTK goes through
.scripts/GTK/
  run-app.sh                 builds an application's GTK head and starts it
  deploy.sh                  builds it for release and lays it in a folder of its own
  test-gtk.sh                runs the host's suite
apps/<App>/Platforms/GTK/
  main.swift                 the application's GTK head
```

## Requirements

The host builds on Linux, on arm64 or x64:

- Swift 6.4 from swift.org - for Debug, its `lldb-dap` has to start: a
  toolchain's LLDB takes the Python library of the distribution it was built
  for, so on another one install that library (a toolchain built for UBI 9
  takes `libpython3.9`, `python39` from the AUR on Arch);
- GTK 4.14 and libadwaita 1.5 or newer, with their headers and pkg-config -
  on Ubuntu 24.04 or newer, `libgtk-4-dev` and `libadwaita-1-dev`;
- gdk-pixbuf's SVG loader, through which GTK reads a vector picture -
  `librsvg2-common`, which a desktop has and a minimal system may not; from
  gdk-pixbuf 2.44, which reads pictures through glycin, glycin's loaders
  (the `glycin` package on Arch);
- WebKitGTK 6.0 with its headers - `libwebkitgtk-6.0-dev` on Ubuntu,
  `webkitgtk-6.0` on Arch - for the web view's backend,
  `lib/Backends/WebView.GTK`: an application showing a web view depends on it
  from its GTK head and calls `StateUIWebViewGTK.register()` before the host
  runs, and the host's own tests register it to prove the web view;
- a desktop session to show the windows in, the test suite's included.

## The head

An application's GTK head is an executable. Its `main` names the application
and hands the thread to the host, under the application's reverse-DNS name:

```swift quote
import NotesUI
import StateUIGTK

stateui_app_register()
StateUIGTK.run(applicationID: "com.example.notes")
```

The name is the one the desktop knows the application by. GTK keeps one
instance of it: launched again, the running application brings its window
forward.

`STATEUI_HOST=gtk` is what makes a build a GTK one: the application's
manifest reads it, declares its `Platforms/GTK` head, the executable it makes,
and defines the `GTK` compilation condition for every module of the
application; `lib/StateUI.Head` brings the `StateUIGTK` host to the head. Swift written for this host alone stands under
`#if GTK`.

A new application made in `apps/` - `.scripts/new-app.sh` - has a GTK head,
as HelloWorld does.

## Controls, acts, and events registered in Swift

An application extends the host from its GTK head. Registrations run before
`StateUIGTK.run`, on the main thread. Registering a contract or an act again
replaces the earlier registration. Every registration is written against the
application's own contracts, so they are `public`: the host lives in a module
of its own and must see them. The Gallery's GTK halves are in
`apps/Gallery/Platforms/GTK/Host/`.

### A control

A control of the application's own is an object that makes and holds the GTK
widget it shows, a `GTKControl`; `StateUIControls.add` says which contract it
realizes:

```swift quote
public static func add<Realized: ElementContract, Made: GTKControl>(
    _ contract: Realized.Type,
    create: @escaping (GTKReports<Realized>) -> Made,
    members: (GTKRegistration<Realized, Made>) -> Void = { _ in })
```

- **`create`** makes the control once per element, and wires what it reports:
  `reports.raise(Contract.member, values)` for an event of the element's own,
  and `reports.report(property, value, as: event)` for a value the USER
  changed.
- **`members`** registers what the control takes: `property(_:_:)` hands a
  value over as the type its contract declares, `nil` where it is no longer
  described, and `raises(_:)` records an event the control raises.

```swift quote
StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightWidget in
    let light = TrafficLightWidget()
    light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
    return light
}) { light in
    light.property(TrafficLightContract.signal) { control, signal in
        control.signal = signal ?? .stop
    }
    light.raises(TrafficLightContract.lampTapped)
}
```

The host places, sizes and shows the control's widget as it does its own -
margins, alignment, opacity, gestures, frame reports - and measures it by the
widget's own measure. A registered control is a leaf: it draws the children
of a contract it names itself, as the next section says. A control that runs a
loop of its own - the Gallery's `Cube3D`, a `GtkGLArea` drawing with OpenGL 3.3
core through libepoxy - turns on its widget's tick callback, which GTK calls
only while the widget is on screen, so nothing turns behind a page the user has
left; a value changed while it is stopped still asks for the one frame it
needs. The same `Cube3D` is drawn with Metal on AppKit: one declaration, each
host drawing it in its own way.

### Children a control draws

A control may draw the children of one contract itself - a map draws its markers.
`children` names their contract and what of each the control realizes, and hands
it every such child, in the tree's order, whenever the element's children
change: one added, moved, taken away, or given another value. A child is a
`GTKChild` - its values read as the types its contract declares, and its own
`reports` to raise its events on it - and stays the same child for as long as
it lives, so the control keeps what it drew for one by it. Such a child has no
widget of its own.

```swift quote
StateUIControls.add(MapContract.self, create: { reports -> MyMap in … }) { map in
    map.property(MapContract.region) { control, region in … }
    map.children(MarkerContract.self, members: [MarkerContract.location, MarkerContract.selected]) { control, markers in
        control.show(markers.map { marker in (marker, marker.value(MarkerContract.location)) })
        // the user taps one: marker.reports.raise(MarkerContract.selected)
    }
}
```

A library element a host does not realize - a `Map` where the platform has no
map of its own - is registered the same way, with the provider and the key it
needs.

This host leaves `Map` and its `Marker` to the application: the platform has
no map of its own, and a map needs a provider and its key, so the host makes
neither (`byApplication` in `GTKRealization.swift`), and the
[platform contract](../platform-contract.md#reading-the-matrix) marks them 🧩.
What the user sees there is the application's own registration. The
`WebView` is a backend, as [Requirements](#requirements) says: the
application's manifest depends on the package `lib/Backends/WebView.GTK` by
its path and its GTK head on that package's `StateUIWebViewGTK`, and the head
calls `StateUIWebViewGTK.register()` before `StateUIGTK.run`, as the
Gallery's does. Until then the host realizes no web view.

### An act

`StateUIActs.add` registers a function the application calls by its act, and
`StateUIActs.add(_:on:_:)` one aimed at the application's own element, handed
that element's control:

```swift quote
StateUIActs.add(GalleryContract.readClipboard) { () -> String in
    clipboardText()
}

StateUIActs.add(RatingBarContract.flash, on: RatingBarWidget.self) { bar in
    bar.flash()
}
```

A performer runs on the main thread, and may await - GTK reads the clipboard
asynchronously - the call answered once it returns. Its arguments and answer
are the act's own types; a call carrying anything else fails with the reason. A thrown error
fails the act, and so does an aim at nothing; an act nobody registered is
refused by name.

### An event without a control

`StateUIEvents.raise` pushes an event of the application's that belongs to no
element, on the UI thread; `StateUIEvents.raises` declares it before the host
runs, so a handler listening for one no source raises is told so.

```swift quote
StateUIEvents.raises(GalleryContract.batteryChanged)
StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
```

## Running

```bash
.scripts/GTK/run-app.sh apps/HelloWorld
```

`run-app.sh` stops a running copy of the head, builds it and starts it, its
output in the terminal. Everything a build writes stays in the application's
`.build/gtk/`, but for what the desktop shows the application by: its icon,
`Resources/AppIcon/appicon_gnome.svg`, and an entry starting this build, both
named by the application's ID and installed for the user in
`~/.local/share/icons` and `~/.local/share/applications`. GNOME finds a
window's icon through that entry. `release` builds the optimized head, `--detach` returns once
the application has started, and `--build-only` builds it and starts
nothing. Every `STATEUI_` variable of the shell that runs it -
`STATEUI_TALLY=1`, `STATEUI_INSPECT=1` - reaches the application.

In VS Code, with **GTK** chosen in the status bar, **StateUI: Debug** builds
the head with `run-app.sh --build-only` and starts it under `lldb-dap`, so a
breakpoint in the application's Swift holds from the first line.

## Deploying

```bash
.scripts/GTK/deploy.sh apps/Gallery artifacts/Gallery/GTK
```

`deploy.sh` builds an application's head for release, as
`run-app.sh release --build-only` does, and lays it in the folder named, made
anew: the head, the StateUI libraries it links, and its pictures in
`Images/`. It lays nothing the system provides - GTK, libadwaita,
WebKitGTK: the machine that runs the folder has them installed.
**StateUI: Deploy** in the editor runs it for the application chosen,
and lays the head in `artifacts/<application>/GTK` of the folder that holds
the application's `apps/` - a checkout's, or a project group's.

## Testing

```bash
swift test --package-path lib/StateUI/StateUI.GTK/Testing
.scripts/GTK/test-gtk.sh --filter GTKConformanceTests/testButton
```

The suite is XCTest. GTK's widgets stand on the test thread with no main loop
running: the suite starts libadwaita once, registers an application for its
windows, and turns GLib's loop itself where GTK lays out and draws. The
windows open on the desktop's display, so the suite runs in a desktop
session. `.scripts/GTK/test-gtk.sh` runs the same `swift test`, handing it
its arguments.

The suite runs the conformance families too, one test a family -
`GTKConformanceTests/testButton` - with the web view's backend registered.
A run holds what it says to `lib/StateUI/exports/`: what the host declares to
`gtk.txt`, and each family's verdicts to `marks/gtk/<Family>.txt`; a run that
says otherwise fails. `STATEUI_UPDATE_EXPORTS=1` writes them instead, each
verdict file under the revision its family stands at in
`lib/StateUI/StateUI.Conformance/revisions.txt`, and `STATEUI_STALE_ONLY=1`
runs only the families whose verdicts stand at another revision, or at none:
each other family's test ends at once. With the verdicts written, the
[platform contract](../platform-contract.md#reading-the-matrix) and
[the control dictionary](../controls/README.md) are rendered from them at the
repository's root:

```bash
STATEUI_UPDATE_EXPORTS=1 .scripts/GTK/test-gtk.sh --filter GTKConformanceTests
STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests
```

In the editor, with GTK chosen, **StateUI: Conformance - Rebuild all** runs
both: the families writing their verdicts, then the documents.
**StateUI: Conformance - Rebuild changed** runs the stale families alone
before it renders.
