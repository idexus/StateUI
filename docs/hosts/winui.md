# WinUI host

The WinUI host renders a StateUI application with WinUI 3 on Windows. It is
Swift, in the application's own process, beside the application module and the
library: it applies the typed sparse patches of the
[host contract](../internals/host-contract.md) directly and calls WinUI through a C++/WinRT
relay behind plain C functions.

A window stands as a Windows application's does: its content under WinUI's
`TitleBar` over a Mica backdrop, the title bar carrying the visible page's
title, the way back, the sidebar's toggle and the page's actions. A
`NavigationStack` shows its top page; a `SplitView`'s sidebar stands in
WinUI's navigation pane, beside the detail in a wide window and over it in a
narrow one; a `TabView`'s tabs stand beneath the title bar.

It presents StateUI's controls, arrangements and pages over the runtime every
host shares - the [platform contract](../platform-contract.md#control-creation) says
which, member by member. A layout paints its box - its background,
outline and shape - and cuts what it holds to it; a scroller reports where the
user moved it on the display's frames and moves where its state says; a state's journey moves every control
tied to it on the display's frames, a property's transition and a layout's
children animate, an engine's placement run stands and draws a ZStack's
children, and a user who turns Windows' animation effects off sees
everything arrive at once. Any other control shows
its name in red where it belongs, so a gap is visible rather than silent.

```text
lib/StateUI/StateUI.WinUI/
  Sources/StateUIWinUI/      the host: its runtime, elements, registrations, layout and window
  Sources/CStateUIWinUI/     the relay: C++/WinRT behind the C functions its header declares
  Testing/                   a package of its own: the host's suite, run by swift test, in Tests/,
                             and the driver every conformance run on WinUI goes through
.scripts/WinUI/
  tools.ps1                  the Windows App SDK's versions, the projection, a directory made self-contained
  run-app.ps1                builds an application's WinUI head and starts it
  deploy.ps1                 builds it for release and lays it in a folder of its own, with what it runs with
  test-winui.ps1             builds and runs the host's suite
apps/<App>/Platforms/WinUI/
  main.swift                 the application's WinUI head
  Host/                      what this host answers for the application
  Relay/                     its C++/WinRT relay, a target of its manifest, where it has one
```

## Requirements

The host builds on Windows 10 1809 or newer, on arm64 or x64:

- Swift 6.4 from swift.org, `swift-6.4.0-RELEASE` - for Debug, its `lldb-dap`
  loads the Python the installer lays beside the toolchain, which
  `lldb-dap --check-python` names;
- Visual Studio 2026 with the C++ tools for the machine's architecture, and
  the Windows SDK 10.0.26100;
- nothing else to install: `tools.ps1` fetches C++/WinRT, the Windows App SDK
  and the WebView2 SDK from nuget.org the first time, each checked against
  nuget.org's own hash, and generates the C++/WinRT projection the relay
  includes.

The web view is a backend, `lib/Backends/WebView.WinUI` - WinUI's `WebView2`
over the system's WebView2 runtime, which WinUI does not ship: an application
showing a web view depends on it from its WinUI head and calls
`StateUIWebViewWinUI.register()` before the host runs.

## Architectures and a deployed head

A head is built for the machine's own architecture. An ARM64 machine builds
an x64 head too, which Windows runs emulated: `run-app.ps1 -Architecture x64`
builds it beside the ARM64 one in `.build\winui`, and lays the x64 Swift
runtime beside it from the merge module the Swift installer keeps in its
`Redistributables`. `deploy.ps1` - **StateUI: Deploy** in the editor - builds
a head for release and lays it in a folder of its own with StateUI, the
Windows App SDK and the Swift and C++ runtimes of its architecture: a folder
that runs on a Windows machine with nothing of them installed. The editor
lays it in `artifacts\<application>\WinUI\<architecture>` of the folder that
holds the application's `apps\`, asking on an ARM64 machine whether for ARM64
or x64. A debugger here follows the machine's own architecture alone.

```powershell
.scripts\WinUI\deploy.ps1 -App apps\Gallery -Destination artifacts\Gallery\WinUI\x64 -Architecture x64
```

## The head

An application's WinUI head is an executable. Its `main` names the
application and hands the thread to the host:

```swift quote
import NotesUI
import StateUIWinUI

stateui_app_register()
StateUIWinUI.run()
```

`STATEUI_HOST=winui` is what makes a build a WinUI one: the application's
manifest reads it, declares its `Platforms/WinUI` head, the executable it
makes, and defines the `WINUI` compilation condition for every module of the
application; `lib/StateUI.Head` brings the `StateUIWinUI` host to the head.
The executable links as a windowed application - `/SUBSYSTEM:WINDOWS` with `/ENTRY:mainCRTStartup` -
so started by itself it opens no console; started from a terminal it writes
there. Swift written for this host
alone stands under `#if WINUI`.

A new application made in `apps/` - `.scripts/new-app.ps1` - has a WinUI
head, as HelloWorld does.

## Controls, acts, and events registered in Swift

An application extends the host from its WinUI head. Registrations run before
`StateUIWinUI.run`, on the main thread. Registering a contract or an act again
replaces the earlier registration. Every registration is written against the
application's own contracts, so they are `public`: the host lives in a module
of its own and must see them. The Gallery's WinUI halves are in
`apps/Gallery/Platforms/WinUI/`: Swift in `Host/`, its C++/WinRT relay in
`Relay/`.

### A control

A control of the application's own is an object holding the WinUI element it
shows, a `WinUIControl`. Swift never calls WinRT itself: the element is made
by a relay of the application's own - C++/WinRT beside its head, behind C
functions, a C++ target of the head's package that includes the projection
the host generated - and handed over as the host's own handles are, a
`UIElement`'s default interface, `AddRef`'d. `StateUIControls.add` says which
contract it realizes:

```swift quote
public static func add<Realized: ElementContract, Made: WinUIControl>(
    _ contract: Realized.Type,
    create: @escaping (WinUIReports<Realized>) -> Made,
    members: (WinUIRegistration<Realized, Made>) -> Void = { _ in })
```

- **`create`** makes the control once per element, and wires what it reports:
  `reports.raise(Contract.member, values)` for an event of the element's own,
  and `reports.report(property, value, as: event)` for a value the USER
  changed.
- **`members`** registers what the control takes: `property(_:_:)` hands a
  value over as the type its contract declares, `nil` where it is no longer
  described, and `raises(_:)` records an event the control raises.

```swift quote
StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightControl in
    let light = TrafficLightControl()
    light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
    return light
}) { light in
    light.property(TrafficLightContract.signal) { control, signal in
        control.signal = signal ?? .stop
    }
    light.raises(TrafficLightContract.lampTapped)
}
```

The host takes a reference of its own to the element and places, sizes and
shows it as it does its own - margins, alignment, opacity, gestures, frame
reports - measuring it by the element's own measure. A registered control is
a leaf: it draws the children of a contract it names itself, as the next
section says. The application's relay tells its Swift half what the user did by a
number the control gave its element, through a table of C callbacks the head
hands it before it runs. A control that draws with the GPU is an element
like any other: the Gallery's `Cube3D` is a `SwapChainPanel` its relay draws
into with Direct3D 11.1, following WinUI's frames only while it spins and
stands on screen - the same declaration Metal draws on AppKit and OpenGL on
GTK.

### Children a control draws

A control may draw the children of one contract itself - a map draws its markers.
`children` names their contract and what of each the control realizes, and hands
it every such child, in the tree's order, whenever the element's children
change: one added, moved, taken away, or given another value. A child is a
`WinUIChild` - its values read as the types its contract declares, and its own
`reports` to raise its events on it - and stays the same child for as long as
it lives, so the control keeps what it drew for one by it. Such a child has no
element of its own.

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
neither (`byApplication` in `WinUIRealization.swift`), and the
[platform contract](../platform-contract.md#reading-the-matrix) marks them 🧩.
What the user sees there is the application's own registration. The
`WebView` is a backend, as [Requirements](#requirements) says: the
application's manifest depends on the package `lib/Backends/WebView.WinUI` by
its path and its WinUI head on that package's `StateUIWebViewWinUI`, and the
head calls `StateUIWebViewWinUI.register()` before `StateUIWinUI.run()`, as
the Gallery's does. Until then the host realizes no web view.

### An act

`StateUIActs.add` registers a function the application calls by its act, and
`StateUIActs.add(_:on:_:)` one aimed at the application's own element, handed
that element's control:

```swift quote
StateUIActs.add(GalleryContract.readClipboard) { () -> String in
    Clipboard.read()
}

StateUIActs.add(RatingBarContract.flash, on: RatingBarControl.self) { bar in
    bar.flash()
}
```

A performer runs on the main thread, and may await, the call answered once it
returns. Its arguments and answer are the act's own types; a call carrying
anything else fails with the reason. A thrown error fails the act, and so does
an aim at nothing; an act nobody registered is refused by name. A performer
may call Win32 itself through `WinSDK` - the Gallery's clipboard does.

### An event without a control

`StateUIEvents.raise` pushes an event of the application's that belongs to no
element, from any thread; `StateUIEvents.raises` declares it before the host
runs, so a handler listening for one no source raises is told so.

```swift quote
StateUIEvents.raises(GalleryContract.batteryChanged)
StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
```

## Running

```powershell
.scripts\WinUI\run-app.ps1 -App apps\HelloWorld
```

`run-app.ps1` builds the head, lays the Windows App SDK beside it and starts
it, passing on what it writes. Everything a build writes stays in the
application's `.build\winui\`. The application carries the Windows App SDK
itself - no package, no installer: its runtime, a manifest registering its
classes and `resources.pri` stand beside the executable. `-Detach` returns once
the application has started. Every `STATEUI_` variable of the shell that runs
it - `STATEUI_TALLY=1`, `STATEUI_INSPECT=1` - reaches the application.

Keep an application's folder near the root of a drive: the Swift compiler on
Windows fails with "the filename or extension is too long" under a deep path.

## Testing

```powershell
.scripts\WinUI\test-winui.ps1
```

The suite is XCTest, run by `swift test` in `lib\StateUI\StateUI.WinUI\Testing`.
WinUI's controls stand on the test thread with no loop of WinUI's running, and
a test lets the thread's messages run where WinUI lays out. The test runner is given
the Windows App SDK as an application is, before the run.

Alone, `test-winui.ps1` runs the host's own tests, each in a process of its
own, one after another.
`-Conformance` runs the conformance families, one test a family -
`WinUIConformanceTests.testButton` - and the longest in parts, each test in a
process of its own, as WinUI keeps GDI objects of every window a test closes
and a process holds only so many: some fifteen minutes. `-Filter` runs the
tests it names, each in a process of its own.

```powershell
.scripts\WinUI\test-winui.ps1 -Filter WinUIConformanceTests.testButton
.scripts\WinUI\test-winui.ps1 -Conformance
```

A run holds what it says to `lib\StateUI\exports\`: the host's own tests what
it declares to `winui.txt`, and each family its verdicts to
`marks\winui\<Family>.txt` - a family run in parts to
`marks\winui\<Family>-<part>.txt`, one file a part; a run that says
otherwise fails. With `STATEUI_UPDATE_EXPORTS=1` in its environment it
writes them instead, each verdict file under the revision its family stands
at in `lib\StateUI\StateUI.Conformance\revisions.txt`. `-Stale` runs only the
families whose verdicts stand at another revision, or at none: each other
one's process ends at once. With the verdicts written,
`swift test --filter ControlDictionaryTests` at the repository's root, with
`STATEUI_UPDATE_DOCS=1` in its environment, renders the
[platform contract](../platform-contract.md#reading-the-matrix) and
[the control dictionary](../controls/README.md) from them. In the editor,
with WinUI chosen, **StateUI: Conformance - Rebuild all** runs both -
`-Conformance` writing its verdicts, then the documents - and
**StateUI: Conformance - Rebuild changed** runs `-Stale` before it renders.
