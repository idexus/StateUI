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
    Platforms/Android                     the Android head: Gradle and a Swift library
        |
        |  depends on
        v
  StateUI  (lib/StateUI, a dynamic library; no Foundation; every platform)
    Sources/Views, Types, Contracts       what an application writes with
    Sources/Core                          state, keys, diffing, cycles, the Wire
    Sources/Host                          the host layer, @_spi(Host)
    Sources/Bridge                        the C exports, for a runtime in another language
        |
        |  typed HostRender / HostPatch
        v
  StateUI.AppKit (lib/StateUI.AppKit)          StateUI.Android (lib/StateUI.Android)
    Swift, in the application's process          Swift, in the application's process,
    links the same StateUI library               Java beneath it through JNI
        |                                             |
        v                                             v
    AppKit views                                  Android views

  lib/StateUI.VSCode                      the editor extension: new application,
                                          build, run and debug for every head
```

Every host is Swift and links the one dynamic StateUI library, so a process
holds one copy of StateUI's types. Code in the platform's own language - Java
through JNI, C++/WinRT behind a C ABI - relays calls beneath the host and holds
no StateUI logic.

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
                                       drained by the host (stateui_run_jobs)
  doorbell thread                      parked in CoreLink.waitForWork();
                                       wakes the UI thread when work arrives
  cooperative pool                     an application's own async work, off MainActor
```

A handler's `await` resumes on `MainActor`, whatever it awaited. The core uses
no platform timer, run loop or main queue: time comes from the host's frame
clock, and work reaches the UI thread through the host's doorbell.

## Where to read next

- [Glossary](glossary.md): StateUI's words and the common term for each.
- [The runtime](host/runtime.md): a host's elements, one frame, one turn and a
  user's change, drawn.
- [Motion in the runtime](host/motion.md) and [patches in the
  runtime](host/patches.md): the reasons behind the host layer's elements.
