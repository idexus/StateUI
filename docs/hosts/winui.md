# WinUI host

The WinUI host renders a StateUI application with WinUI 3 on Windows. It is
Swift, in the application's own process, beside the application module and the
library: it applies the typed sparse patches of the
[host contract](host-contract.md) directly and calls WinUI through a C++/WinRT
relay behind plain C functions.

A window stands as a Windows application's does: its content under WinUI's
`TitleBar` over a Mica backdrop, the title bar carrying the visible page's
title, the way back, the sidebar's toggle and the page's actions. A
`NavigationStack` shows its top page; a `SplitView`'s sidebar stands in
WinUI's navigation pane, beside the detail in a wide window and over it in a
narrow one; a `TabbedView`'s tabs stand beneath the title bar.

It presents `Label`, `Button`, `Switch`, `Slider`, `TextField`, `ColorBox`,
`VStack`, `HStack`, `Grid`, `ZStack` and `ScrollView` in a window's page,
over the runtime every host shares: a layout paints its box - its background,
outline and shape - and cuts what it holds to it; a scroller reports where the
user moved it on the display's frames and moves where its state says; a state's journey moves every control
tied to it on the display's frames, a property's transition and a layout's
children animate, an engine's placement run stands and draws a ZStack's
children, and a user who turns Windows' animation effects off sees
everything arrive at once. Any other control shows
its name in red where it belongs, so a gap is visible rather than silent.

```text
lib/StateUI.WinUI/
  Sources/StateUIWinUI/      the host: its runtime, elements, registrations, layout and window
  Sources/CStateUIWinUI/     the relay: C++/WinRT behind the C functions its header declares
  Tests/                     the host's suite, run by swift test
.scripts/WinUI/
  tools.ps1                  the Windows App SDK's versions, the projection, a directory made self-contained
  run-app.ps1                builds an application's WinUI head and starts it
  test-winui.ps1             builds and runs the host's suite
apps/<App>/Platforms/WinUI/
  main.swift                 the application's WinUI head
```

## Requirements

The host builds on Windows 10 1809 or newer, on arm64 or x64:

- Swift 6.4 from swift.org, `swift-6.4.0-RELEASE`;
- Visual Studio 2026 with the C++ tools for the machine's architecture, and
  the Windows SDK 10.0.26100;
- nothing else to install: `tools.ps1` fetches C++/WinRT and the Windows App
  SDK from nuget.org the first time, each checked against nuget.org's own
  hash, and generates the C++/WinRT projection the relay includes.

## The head

An application's WinUI head is an executable. Its `main` names the
application and hands the thread to the host:

```swift quote
import NotesUI
import StateUIWinUI

stateui_app_register()
StateUIWinUI.run()
```

`STATEUI_WINUI=1` is what makes a build a WinUI one: the application's
manifest reads it, declares the `Platforms/WinUI` target, the executable it
makes and the `StateUIWinUI` dependency, and defines the `WINUI` compilation
condition for every module of the application. The executable links as a
windowed application - `/SUBSYSTEM:WINDOWS` with `/ENTRY:mainCRTStartup` -
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
`apps/Gallery/Platforms/WinUI/Host/`.

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
a leaf. The application's relay tells its Swift half what the user did by a
number the control gave its element, through a table of C callbacks the head
hands it before it runs. A control that draws with the GPU is an element
like any other: the Gallery's `Cube3D` is a `SwapChainPanel` its relay draws
into with Direct3D 11.1, following WinUI's frames only while it spins and
stands on screen - the same declaration Metal draws on AppKit and OpenGL on
GTK.

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
application's `.build-winui\`. The application carries the Windows App SDK
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

The suite is XCTest, run by `swift test` in `lib\StateUI.WinUI`. WinUI's
controls stand on the test thread with no loop of WinUI's running, and a test
lets the thread's messages run where WinUI lays out. The test runner is given
the Windows App SDK as an application is, before the run.
