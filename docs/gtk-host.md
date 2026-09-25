# GTK host

The GTK host renders a StateUI application with GTK 4 and libadwaita on
Linux. It is Swift, in the application's own process, beside the application
module and the library: it applies the typed sparse patches of the
[host contract](host-contract.md) directly and calls GTK and libadwaita
through their C API, with nothing beneath it in another language.

It presents its first controls - `Label`, `Button`, `Switch`, `Slider`,
`TextField` and `ColorBox`, the layouts `VStack`, `HStack`, `Grid`, `ZStack`
and `ScrollView`, and the arrangements `NavigationStack`, `SplitView` and
`TabbedView` - each page under a header bar of its own that slides with it, a
sidebar beside the detail or over it in a narrow window, tabs chosen by a
switcher in the header bar, as GNOME's applications stand - over the runtime
every host shares. A switch, a slider and a field carry their states
both ways; opacity, sizes and transforms animate, a turn in depth included,
a stack's children travel to their new places, and a child the tree hides
fades out first. A layout paints its own box and cuts what it holds to it.
It shows any other control's name in red where the control belongs, so a gap
is visible rather than silent. It looks as the desktop's own
applications do: libadwaita's widgets, and the light or dark style the desktop
is set to.

```text
lib/StateUI.GTK/
  Sources/StateUIGTK/        the host: its runtime, elements, registrations, layout and window
  Sources/CStateUIGTK/       GTK's and libadwaita's headers, found by pkg-config
  Tests/                     the host's suite, run by swift test
.scripts/GTK/
  run-app.sh                 builds an application's GTK head and starts it
apps/<App>/Platforms/GTK/
  main.swift                 the application's GTK head
```

## Requirements

The host builds on Linux, on arm64 or x64:

- Swift 6.4 from swift.org;
- GTK 4.14 and libadwaita 1.5 or newer, with their headers and pkg-config -
  on Ubuntu 24.04 or newer, `libgtk-4-dev` and `libadwaita-1-dev`;
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

`STATEUI_GTK=1` is what makes a build a GTK one: the application's manifest
reads it, declares the `Platforms/GTK` target, the executable it makes and the
`StateUIGTK` dependency, and defines the `GTK` compilation condition for every
module of the application. Swift written for this host alone stands under
`#if GTK`.

A new application made in `apps/` - `.scripts/new-app.sh` - has a GTK head,
as HelloWorld does.

## Running

```bash
.scripts/GTK/run-app.sh apps/HelloWorld
```

`run-app.sh` stops a running copy of the head, builds it and starts it, its
output in the terminal. Everything a build writes stays in the application's
`.build-gtk/`, but for what the desktop shows the application by: its icon,
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

## Testing

```bash
swift test --package-path lib/StateUI.GTK
```

The suite is XCTest. GTK's widgets stand on the test thread with no main loop
running: the suite starts libadwaita once, registers an application for its
windows, and turns GLib's loop itself where GTK lays out and draws. The
windows open on the desktop's display, so the suite runs in a desktop
session.
