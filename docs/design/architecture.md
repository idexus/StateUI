# Architecture

StateUI is a Swift core that describes native interfaces, and hosts that show
the description with each platform's own toolkit. This page draws the whole:
the packages, what crosses between them, and where each part of the work runs.
[The runtime](host/runtime.md) draws a host's inside.

## The packages

```text
  apps/<App>                              one Swift package per application
    Sources/                              views, @State, handlers, engines
    Platforms/AppKit                      the AppKit head: an executable
    Platforms/UIKit                       the UIKit head: an application bundle
    Platforms/Android                     the Android head: Gradle and a Swift library
    Platforms/WinUI                       the WinUI head: an executable
    Platforms/GTK                         the GTK head: an executable
    Platforms/Web                         the Web head: a WebAssembly module and its page
        |
        |  depends on
        v
  StateUI  (lib/StateUI/Core; no Foundation; every platform)
    Sources/Views, Types, Contracts       what an application writes with
    Sources/Core                          state, keys, diffing, cycles, the typed boundary
        |
        |  @_spi(Host)
        v
  StateUIHost  (lib/StateUI/StateUI.Host)
    Sources                               the host layer every host stands on
        |
        |  typed HostRender / HostPatch
        v
  StateUI.AppKit (lib/StateUI/StateUI.AppKit)    StateUI.UIKit (lib/StateUI/StateUI.UIKit)
    Swift over AppKit                            Swift over UIKit
        |                                             |
        v                                             v
    AppKit views                                  UIKit views

  StateUI.Android (lib/StateUI/StateUI.Android)  StateUI.WinUI (lib/StateUI/StateUI.WinUI)
    Swift, Java beneath it through JNI           Swift, C++/WinRT beneath it behind a C ABI
        |                                             |
        v                                             v
    Android views                                 WinUI 3 elements

  StateUI.GTK (lib/StateUI/StateUI.GTK)          StateUI.Web (lib/StateUI/StateUI.Web)
    Swift over GTK 4's and libadwaita's C API    Swift in WebAssembly, JavaScript beneath it
        |                                             |
        v                                             v
    GTK widgets                                   DOM elements

  lib/Backends/<Element>.<Host>           a backend: one element on one host, its engine a
                                          library the platform does not ship - WebView.GTK,
                                          WebView.WinUI - registered by the application's head
  lib/StateUI/StateUI.Conformance         the conformance families every host's tests run
  lib/StateUI.Head                        StateUIHead: what every head is built with - the
                                          host STATEUI_HOST names, re-exported
  editors/VSCode                          the editor extension: new application,
                                          build, run and debug for every head
```

Every host is Swift. On a native platform it links the one dynamic StateUI
library, so a process holds one copy of StateUI's types; a Web build links the
application, StateUI and its host into one WebAssembly module, as WebAssembly
links no library dynamically. Code in the platform's own language - Java
through JNI, C++/WinRT behind a C ABI, JavaScript in the page - relays calls
beneath the host and holds no StateUI logic.

## One change, end to end

```text
  the user taps a button              the user drags a slider
        |                                   |
        v                                   v
  handler on MainActor                report through CoreLink
  writes @State                       lands on the state, no rebuild
        |                                   |
        +-----------------+-----------------+
                          |
          a body read it  |  a control is bound to it
          (path 1)        |  (path 2)
                          v
  render: rebuild the bodies that read it, diff by key -> HostPatch
  cycle:  engines and conversions -> the bound states' changes
                          |
                          v
  host: PatchIntake applies the patch; StateChannels carry the bound values;
        Animator animates both; one walk of the tree sets native properties
                          |
                          v
                   native views on screen
```

The core owns state, keys, diffing, the timing laws and the engines. The host
owns native objects, their lifetime, input, layout integration and the display
frame, and never computes again what the core decides.

## Threads

```text
  UI thread                            MainActor: handlers, renders, the host's work
    runs jobs the core queues          main queue on Apple; UIThreadExecutor elsewhere,
                                       drained by the host (CoreLink.runJobs())
  cooperative pool                     an application's own async work, off MainActor
  WebAssembly                          one thread and no pool: every task runs on
                                       UIThreadExecutor, drained in the turn each
                                       call from the page ends with
```

A handler's `await` resumes on `MainActor`, whatever it awaited. The core uses
no platform timer or run loop, and the main queue only for the one drain it
posts where something turns that queue: time comes from the host's frame
clock, and work reaches the UI thread through the host's turn: after each pass
of the main run loop on Apple, as each call from the page ends on the Web,
posted elsewhere - by the thread that made the work, the UI thread's own or
another queueing a job.

## The public surface

What an application can name of the library is recorded:
`lib/StateUI/exports/api/` holds every public declaration of the
`StateUI` module, a line each - its kind, its path and its declaration as the
compiler prints it - and every conformance of its types, sorted, read from the symbol graph the toolchain extracts
from the module the core's tests just built. The compiler's API digest supplies
public accessor access and synthesized projections that the symbol graph omits.
The graph remains the public surface's filter, so private and SPI projections
stay out. `APISurfaceTests` compares the
module with the record, so a change to the public API stands in its commit's
diff as lines added and taken away, and passes only once
`STATEUI_UPDATE_EXPORTS=1` has written it. `@_spi(Host)` declarations are the
hosts' and stay out; documentation changes nothing there.

Compiled fixtures prove that changing a setter's access, a projection or actor
isolation changes the record. Public-client checks also prove the boundary:
reported facts can be read, while application-owned settings lend writable
bindings. Both use the compiler and module under test, with no handwritten
projection inventory in the exporter.

The record holds StateUI's declarations and each type's conformances. A
member another module's protocol lends a StateUI type - `!=` from `Equatable`,
`hashValue`, a set's `union(_:)`, an integer's `init(bigEndian:)` once StateUI
extends `Int` - is that module's: the record leaves it out and says the
conformance that brings it, `swift.conformance Icon: Swift.Hashable`. What the
standard library lends changes with the toolchain - Windows' extractor alone
loads the regex parser, whose members reach every describable type - while a
conformance is StateUI's word. Every type is `Copyable` and `Escapable` unless
it says otherwise, so those stay out, and an extended type of another module
lists only the StateUI protocols it takes.

The record is the same on every system. The extractor is the one of the
toolchain that built the module - beside `swift` on PATH, else Xcode's, whose
`swift` on PATH is a shim. It reads the standard library from the SDK -
Xcode's on macOS, the one `SDKROOT` names on Windows.

## Two surfaces

The record stands in two files, one per surface. `StateUI.txt` is what an
application writes: its views and their modifiers, its states, sessions and
values. `StateUI.extending.txt` is what an author adding to StateUI writes - an
element of the application's own, a value a state carries, the application's
own acts and events: a contract and its members, a node and what is written
on it by member (`setValue`, `onEvent`, `onHostEvent`, `modified`, `node`), the
values a host is handed, a value's conversions and wire codes (`rawValue`,
`list(from:)`), what a kept value is handed to the store as, what a contract
declares of its element (`nodeType`, `layer`, `tiers`, `members`),
`application.call` and `HostEvents` - so the application's file names no
`PropValue` and no existential but the key paths the language asks for. A
protocol a control and its style wear - a control's
`…Properties`, a tier's `…Element` - stands there as a declaration and as each
conformance to it, while its members, the modifiers, are the application's.
`APISurfaceTests` keeps the two lists, `extendingTypes` and `extendingMembers`,
and every line goes to exactly one file. A type of the application's file is
one an application meets: one it writes itself - a protocol it adopts, an
object it makes, a view, a scene, an error it catches, a namespace it calls, a
contract - or one another of its declarations names. A value only a contract's
member, a host or the store takes - a corner radius, a keyboard shortcut, a
web view's source - is the extending file's. Both are frozen alike at 1.0: an
application's own control is an extension of the protocol every library
control wears, so the plumbing stays on the views and the second file names
it. The handbook's [Extending StateUI](../interface/extending.md) teaches it.
Every public type of either file is named on a handbook page - README and
`docs/`, the design notes left out, the control dictionary in -
which `APISurfaceTests` holds: what 1.0 freezes is what the handbook
promised.

## A host's modules

What an application writes for a host is recorded too, a file a module beside
StateUI's two: each facade (`StateUIAppKit.txt`, `StateUIUIKit.txt`,
`StateUIAndroid.txt`, `StateUIWinUI.txt`, `StateUIGTK.txt`, `StateUIWeb.txt`),
each backend (`StateUIWebViewGTK.txt`, `StateUIWebViewWinUI.txt`) and the
testing module (`StateUITesting.txt`). The core's `APISurfaceTests` stays the
one reading of a surface: a host's test script, after its build, runs its
`testTheModuleAHostsScriptNamesIsItsRecord` through `.scripts/API/record.sh`
(`record.ps1` on Windows), naming the module, the folder its build left the
modules in, and - for a build for another platform - the triple, the SDK and
what finds the module's C modules (their maps, pkg-config's flags). The record
is written under `STATEUI_UPDATE_EXPORTS=1` and held otherwise, as the marks
are. The script reads it where the module was built: the simulator's, an
Android device's and the WebAssembly build's tests run where no toolchain is,
so the test cannot read its own module. The core's own run names no module and
the test stands skipped, saying so. The handbook names every public type of
every record, the hosts' included.

## Where to read next

- [Glossary](glossary.md): StateUI's words and the common term for each.
- [The runtime](host/runtime.md): a host's elements, one frame, one turn and a
  user's change, drawn.
- [Motion in the runtime](host/motion.md) and [patches in the
  runtime](host/patches.md): the reasons behind the host layer's elements.
