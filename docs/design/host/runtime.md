# The runtime

A runtime is the part of a host that turns the core's patches and cycles into
native views, and turns what the user does back into state. Every runtime has
the same elements, one job each, named alike in every language. The
toolkit-neutral elements are the core's host layer, `lib/StateUI/Sources/Host`,
behind `@_spi(Host)`: every Swift host uses them as they are, and a runtime in
another language ports them and proves the port against the same fixtures.

## The layers

```text
  application              views, @State, handlers, engines
       |
       v
  StateUI core             state, keys, diffing, timing laws        lib/StateUI/Sources
       |                   HostRender / HostPatch (typed)   Wire (bytes)
       |                                                      |
       v                                                      v
  host layer               CoreLink        PatchIntake        runtime in another language
  @_spi(Host)              Walker          StateChannels      (C#: lib/StateUI.Maui),
  Sources/Host             DescribedMotion ProgramWrite       the same elements, ported
       |
       v
  toolkit half             frame signal, display cycle, mounted tree,
  one package per host     realizations, layout views, scrolling, gestures,
  (lib/StateUI.AppKit)     focus, accessibility, windows and menus
       |
       v
  native views
```

A Swift host links the core's dynamic library and takes the typed patch, so one
process holds one copy of StateUI's types. The Wire is the same patch as bytes,
for a runtime that cannot read Swift types.

## The parts

Every element serves one part of the core's model: one `@State`, two reactive
paths, the journey's animations and the frame they run on.

| Part | What it is | Elements | Home |
| --- | --- | --- | --- |
| S | one `@State` is one state channel, shared by every control bound to it | `StateChannels` | host layer |
| D | reactive path 1: a body rebuilds, is diffed, arrives as a patch | `PatchIntake`, `DescribedMotion` | host layer |
| | | the mounted tree, one realization per control family, `LayoutMotion`, the handler queue | toolkit half |
| C | reactive path 2: a value reaches a native control with no rebuild, and the user's change comes back | `ProgramWrite` | host layer |
| | | the user's reports | toolkit half |
| J | a journey's animations, walked by the host | `Walker`, `Trip`, `TripTarget`; the laws are `HostMotionLaw` in the core | host layer |
| E | the frame engines and animations run on | the frame clock, the display cycle | toolkit half |
| P | presenting what D describes, reporting the user into C | layout, scrolling, gestures, drawing, focus, accessibility, windows, menus | toolkit half |
| B | transport and process | `CoreLink`; `Registry` is the core's | host layer |
| | | the pump, the act performer | toolkit half |

## One frame

The frame clock ticks only while something holds it. Each tick runs one
display cycle, in this order, in every runtime:

```text
  frame clock tick (now, in ms on one monotonic clock)
    |
    1  the user's reports since the last frame     committed as one batch
    2  Walker.step(now)                            StateChannels, DescribedMotion and
                                                   LayoutMotion follow the steps;
                                                   the channels' reports reach the core
    3  CoreLink.cycle(now)                         engines and conversions run in the core;
                                                   StateChannels take the changes
    4  one walk of the mounted tree                each element's native setters once,
                                                   each changed parent arranged once,
                                                   after its children;
                                                   finished animations answer their waiters
    5  a render, when the core needs one
    6  the clock stays held while anything moves; it lets go only here
```

A user's own change drains steps 2 to 4 and 6 at once, so the followers and
the engines move on the user's frame.

## One turn

A thread parked in `CoreLink.waitForWork()` wakes the UI thread whenever the
core has work: a job on `MainActor`, a cycle, a render or an act. The turn
always runs in the same order.

```text
  doorbell thread: CoreLink.waitForWork() returns
    |  posts one turn to the UI thread
    v
  pump:  run the jobs  ->  a pending cycle  ->  render  ->  acts
                                                  |
                                                  v
                          PatchIntake.take(root, generation)
                            ProgramWrite marks the writes, handlers wait
                            the mounted tree applies the patch
                            a drift: refused, and render(baseline: 0) once
                            the generation is claimed only when it went in whole
```

The acts come last, so an act lands on the interface its handler just changed.

## A user's change

```text
  a native callback: a slider moved, a field typed into
    |
    +-- inside ProgramWrite: the program's own echo, dropped
    |
    v
  StateChannels.take       the animation stops where the user holds the value
  every other control      bound to the state wears the value in the same walk
  CoreLink.report          the core has the value
  the display cycle        drains at once: followers and engines move now
    |
    v
  the handler runs, and reads the user's value already in the state
```

## The host layer

The toolkit-neutral elements live once, in the core, because every Swift host
would otherwise carry its own copy of the same arithmetic and rules: the
animations, the state channels, the property animations of a patch, the one
mark of a program's write, the patch intake and the line to the core. The core
suite tests them on every platform the core builds on, and
`RuntimeArchitectureTests` holds every Swift runtime to them: only `Walker`
samples a timing law, only `CoreLink` calls into the core, only `ProgramWrite`
marks a write, and no runtime type is an engine or a channel other than a
state's. [Motion](motion.md) gives the reasons of the walker, the state
channels and the described motion; [patches](patches.md) those of the patch
intake and the program write.

## Core link

A runtime calls the running core through `CoreLink` alone: a render, a cycle,
an event, an act call and its answer, a user's report, the application's and
the scene's reports, the kept values and the doorbell's wait. For a Swift host
the line is the typed `StateUIHost` SPI; a runtime in another language holds
the same element over the Wire. The lane codecs - a journey read from its
image and written back, a placement run - are arithmetic on values the runtime
already holds, and stay the SPI's.

## Names

An element's name is its stem: `Walker`, `StateChannels`, `PatchIntake`. The
host layer uses the stem; a Swift host prefixes its toolkit to what only it
has (`AppKitFrameClock`); a runtime in another language uses the stem in its
namespace. A native subclass keeps its toolkit's class word
(`AppKitScrollView`). Some words are reserved: an **engine** is only
application frame code, a **channel** only a state's, a **trip** one animated
value, a **cycle** only the display cycle, a **report** only the user's change
on its way to the core, and an **act** is a call the application makes on a
control. [The glossary](../glossary.md) maps every StateUI term to the common one.
