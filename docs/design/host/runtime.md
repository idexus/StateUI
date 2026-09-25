# The runtime

A runtime is the part of a host that turns the core's patches and cycles into
native views, and turns what the user does back into state. Every runtime has
the same elements, one job each, named alike in every language. The
toolkit-neutral elements are the core's host layer, `lib/StateUI/Sources/Host`,
behind `@_spi(Host)`, and every host - Swift in the application's process -
uses them as they are.
Its folders follow these notes: `Runtime`, `Tree`, `Layout` and `Motion`.

## The layers

```text
  application              views, @State, handlers, engines
       |
       v
  StateUI core             state, keys, diffing, timing laws        lib/StateUI/Sources
       |                   HostRender / HostPatch (typed)
       v
  host layer               CoreLink        PatchIntake
  @_spi(Host)              MountedTree     MountedElement
  Sources/Host             Animator        StateChannels
                           DescribedMotion LayoutMotion
                           DisplayCycle    ProgramWrite
                           Pump            HandlerDispatch
       |
       v
  toolkit half             frame signal, each element's native half,
  one package per host     realizations, layout views, scrolling, gestures,
  (lib/StateUI.AppKit,     focus, accessibility, windows and menus
  lib/StateUI.Android,
  lib/StateUI.WinUI,
  lib/StateUI.GTK)
       |
       v
  native views
```

A host links the core's dynamic library and takes the typed patch, so one
process holds one copy of StateUI's types.

## The parts

Every element serves one part of the core's model: one `@State`, two reactive
paths, the journey's animations and the frame they run on.

| Part | What it is | Elements | Home |
| --- | --- | --- | --- |
| S | one `@State` is one state channel, shared by every control bound to it | `StateChannels` | host layer |
| D | reactive path 1: a body rebuilds, is diffed, arrives as a patch | `PatchIntake`, `MountedTree`, `MountedElement`, `DescribedMotion`, `LayoutMotion` | host layer |
| | | `HandlerDispatch` | host layer |
| | | each element's native half (`NativeElement`), one realization per control family | toolkit half |
| C | reactive path 2: a value reaches a native control with no rebuild, and the user's change comes back | `ProgramWrite` | host layer |
| | | the user's reports | toolkit half |
| J | a journey's animations, run by the host | `Animator`, `Animation`, `AnimationTarget`; the laws are `HostMotionLaw` in the core | host layer |
| E | the frame engines and animations run on | `DisplayCycle`; the `FrameClock` protocol | host layer |
| | | the frame signal: the toolkit's display link | toolkit half |
| P | presenting what D describes, reporting the user into C | the layout arithmetic: `StackArithmetic`, `GridArithmetic`, `ZStackArithmetic`, `SingleChildArithmetic`, `ScrollArithmetic`, `MeasurementCache` | host layer |
| | | the layout views, scrolling, gestures, drawing, focus, accessibility, windows, menus | toolkit half |
| B | transport and process | `CoreLink`; `Registry` is the core's | host layer |
| | | `Pump` | host layer |
| | | the doorbell's post, the act performer | toolkit half |

## One frame

The frame clock ticks only while something holds it. Each tick runs one
display cycle, in this order, in every runtime:

```text
  frame clock tick (now, in ms on one monotonic clock)
    |
    1  the user's reports since the last frame     committed as one batch
    2  Animator.advance(to: now)                   StateChannels, DescribedMotion and
                                                   LayoutMotion follow the animations;
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

`Pump` is that turn, once for every runtime. A toolkit gives it a
`TurnPresenter`: what a render changed around the tree - the windows, their
pages, their chrome - and the performer of an act. A turn asked for while one
runs runs when it ends; the handlers a render created run and the turn goes
round again; the handlers waiting in `HandlerDispatch` run, a phase rendered
before what comes after it, and the turn goes round again; only then the acts.

## The handlers' order

The application's handlers run in the order the user caused them, each on the
interface the last one left. `HandlerDispatch` holds a handler raised while a
patch applies - the tree is half old, half new until the patch is in - and
one raised inside the user's transaction, a gesture that changes two things at
once, such as a radio button turning one off and the next on. Both run in
their order once the hold is over. A turn asked for inside the transaction,
by a report that wrote a state, waits for it too: the two halves of one
gesture render together or not at all.

A page's or a window's phase - it showed, it went - is queued as a phase. It
is rendered before the handler after it runs, so an application watching the
phase sees each one.

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
mounted tree and its patches, the animations, the state channels, the property
and layout animations, the display cycle's order, the one mark of a program's
write, a scroller's movement, the patch intake and the line to the core. A toolkit gives the layer
each element's native half through `NativeElement`, its frame signal through
`FrameClock`, presents a frame through `FramePresenter` and a turn through
`TurnPresenter`, and hands
`LayoutMotion` the views it places as `PlacedView`. The core suite tests them
on every platform the core builds on, and `RuntimeArchitectureTests` holds
every Swift runtime to them: only `Animator` samples a timing law, only
`DisplayCycle` advances the animator and runs the core's cycle, only `Pump`
renders and takes the acts, only `CoreLink`
calls into the core, only `ProgramWrite` marks a write, and no runtime type is
an engine or a channel other than a state's. [Motion](motion.md) gives the
reasons of the animator, the state channels, the described motion and the layout
motion; [patches](patches.md) those of the patch intake and the program write;
[the mounted tree](tree.md) those of the tree and its native halves;
[layout](layout.md) those of the layout arithmetic.

## A scroller's movement

The scrolling is the platform's: a drag, a throw, a wheel and a key move a
scroller under its toolkit's own physics, and nothing in a host aims,
shortens or corrects them. `ScrollMovement` adds what no toolkit says in one
shape: where a movement went, frame by frame, and when it is over.

Reports wait for the display's frame. A toolkit moves a scroller from inside
its own frame step, and a report rendered there would hold that frame; so a
move joins the move before it, and a frame says where the scroller went
rather than every step.

Rest is said once per movement, and only when the offset moved. While the
user holds the scroller - a live scroll, a finger down - it cannot rest. A
hold that ran its throw out itself, as a desktop's live scroll does, rests
as it ends; a finger let go leaves the scroller to throw on by itself, and
that, like a movement nobody held, rests once the offset has stood still for
`restAfter` of the frame clock's time. A hold that catches a throw carries
its movement on, so it still rests once. A moving scroller keeps the frames
coming, so the quiet is counted in the display's own time and a hand-wound
clock reproduces every rest.

## A swipe

A host whose toolkit tells it a press and how far it has moved, and no swipe,
tells a swipe by one rule (`SwipeDirection.swiped`): the press went the one
way it moved most - across when it moved at least as far across as down - if
that movement reaches the view's threshold and the view listens for that way.
A way it does not listen for is no swipe, even where the press also moved far
along the other axis: the dominant way decides, never a second one.

## Core link

A runtime calls the running core through `CoreLink` alone: a render, a cycle,
an event, an act call and its answer, a user's report, the application's and
the scene's reports, the kept values and the doorbell's wait. The line is the
typed `StateUIHost` SPI. The lane codecs - a journey read from its
image and written back, a placement run - are arithmetic on values the runtime
already holds, and stay the SPI's.

## Names

An element's name is its stem: `Animator`, `StateChannels`, `PatchIntake`. The
host layer uses the stem; a host prefixes its toolkit to what only it has
(`AppKitFrameClock`). A native subclass keeps its toolkit's class word
(`AppKitScrollView`). Some words are reserved: an **engine** is only
application frame code, a **channel** only a state's, an **animation** one
animated value, a **cycle** only the display cycle, a **report** only the
user's change on its way to the core, and an **act** is a call the
application makes on a control. [The glossary](../glossary.md) maps every
StateUI term to the common one.
