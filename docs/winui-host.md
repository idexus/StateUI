# WinUI host

The WinUI host renders a StateUI application with WinUI 3 on Windows. It is
Swift, in the application's own process, beside the application module and the
library: it applies the typed sparse patches of the
[host contract](host-contract.md) directly and calls WinUI through a C++/WinRT
relay behind plain C functions.

It presents its first controls - `Label`, `Button`, `VStack` and `HStack` -
and a window's page, over the runtime every host shares, and shows any other
control's name in red where the control belongs, so a gap is visible rather
than silent.

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
  the Windows SDK 10.0.26100, whose `mt.exe` gives an application its
  manifest;
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
condition for every module of the application. Swift written for this host
alone stands under `#if WINUI`.

A new application made in `apps/` - `.scripts/new-app.ps1` - has a WinUI
head, as HelloWorld does.

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
