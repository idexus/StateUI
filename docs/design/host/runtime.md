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
| | | a user's change carried onto its state and its event, a radio set, a scroller's move (`MountedElement.reportUserChange`) | host layer |
| | | the native callback that hears the user | toolkit half |
| J | a journey's animations, run by the host | `Animator`, `Animation`, `AnimationTarget`; the laws are `HostMotionLaw` in the core | host layer |
| E | the frame engines and animations run on | `DisplayCycle`; the `FrameClock` protocol | host layer |
| | | the frame signal: the toolkit's display link | toolkit half |
| P | presenting what D describes, reporting the user into C | the layout arithmetic: `StackArithmetic`, `GridArithmetic`, `ZStackArithmetic`, `SingleChildArithmetic`, `ScrollArithmetic`, `MeasurementCache` | host layer |
| | | the layout views, scrolling, gestures, drawing, focus, accessibility, windows, menus | toolkit half |
| B | transport and process | `CoreLink`; `Registry` is the core's | host layer |
| | | `Pump`; `HostRuntime` wires every part above | host layer |
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

The carrying is the host layer's, the same on every host
(`MountedElement.reportUserChange`): what the program writes reports
nothing; a value becomes the state's - a journey a carried property's channel
takes, else a report - and then its event runs, or a turn renders what the
state changed where no handler listens. A radio button checked takes its
set's other checks away first, in one user's transaction: each peer turned off
on its own control as the program, then reporting that it is off. A host's
native callback hands the value on, and turns a peer's control off in its
toolkit's terms.

## The runtime's parts

`HostRuntime` builds the parts every host holds alike and wires them once: the
core's link, the patch's intake, the animator, the state channels and the two
motions, the display cycle on the host's frame clock, the mounted tree and the
pump - the clock's frames run the cycle, a layout motion or an animation
starting holds the clock. It is also every road a user's change takes in: a
dispatch, a user's transaction, a report through a bound state, a journey
taken, a gesture's value. A host gives it its frame clock and how an element's
native half is made, and presents a turn's and a frame's end.

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

## Where a view stands

An element whose frame the tree reads - a state its frame drives, or a
handler of its changes - says where it stands on the display's next frame
after anything was laid out or moved: its place in its parent onto the
state, the whole report to its handler, and nothing where the report is the
one it last said (`MountedElement.reportFrame`). The runtime's
`FrameFollowers` keeps the frames coming while a scroller moves or has
something to say, or a frame read may have moved, and on each frame lets the
scrollers say what they did, then the elements where they stand, each in the
order its view was made, as one user's transaction. A host says only what its
toolkit knows: the numbers of the place.

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

## What the user does with a finger

What the user does to a view with a finger, a pen or the mouse becomes the
element's events by one rule on every host (`MountedElement.hearing`,
`hear`): a view listens for taps where a handler hears them, for the pointer,
for a press dragged where a pan, a swipe or a state a pan carries asks - one
pointer's alone - and for a pinch. A tap answers each time a quick run
reaches the count asked for, and at once for a press assistive technology
made; the pointer says where it is, but not as it enters or leaves; a press
dragged moves the states it carries by how far it has come from where they
stood as it began, in one user's transaction, and is a swipe as it ends far
enough ([a swipe](#a-swipe)); a pinch says each step's scale since the last
and where, as shares of the view (`PinchStep`). A host's toolkit hears the
input and says it as `HeardInput`.

## A swipe

A host whose toolkit tells it a press and how far it has moved, and no swipe,
tells a swipe by one rule (`SwipeDirection.swiped`): the press went the one
way it moved most - across when it moved at least as far across as down - if
that movement reaches the view's threshold and the view listens for that way.
A way it does not listen for is no swipe, even where the press also moved far
along the other axis: the dominant way decides, never a second one.

## Acts

An act the application calls is answered on every host the same way: with
a reply carrying its values, or a failure carrying the reason - a caller
waiting on it throws that, and one nobody waits on goes to the host's log - so
no caller waits on an act nobody performs. An act aimed at a view names it by
its first argument, the element's own id or its number; one naming none, or
none on screen, fails with that reason (`MountedTree.aimed`). A host performs
the act in its toolkit's terms and nothing more.

## Questions for the user

A question - an alert, a confirmation, a choice of actions, a prompt - is
read from its act the same way on every host (`HostQuestion`): its title and
message, the accepting caption ("OK" where it names none), the cancelling one
("Cancel" for a confirmation or a prompt; a choice's only where it names
one), a choice's dangerous action and its others, a prompt's placeholder,
bound, purpose and starting words. It answers as its kind does: a
confirmation yes or no, a choice or a prompt its words where the user
accepted and nothing where not, an alert nothing. Questions show one at a
time in the order asked, each under a ticket of its own across the process
(`QuestionQueue`), so an answer after its runtime has gone answers nothing
of another's.

## Kept values

A host whose platform keeps no store an application can use keeps the
application's kept values in a file of its own, and one codec says what the
file holds (`KeptValuesText`): a line a key, its name and its words apart by
a tab - a tab, a line's end and a backslash in either escaped - the keys in
order, so the same values write the same file. A value is kept as the words
its key's kind reads back; a key the application does not list, or a value of
another kind, is not kept. Where the file stands and how it is read and
written is the host's.

## A value in a range

A value a control holds inside a range - a slider's, a stepper's, a progress
bar's - follows one arithmetic on every host (`ValueArithmetic`): the range's
ends stand in order whichever the tree gave first; a step that does not move
is 1; a share of work past an end stands at that end, one that is no number
at the start; a slider's key moves a hundredth of its range and a page a
tenth; and a stepped number is written with as many decimals as its step,
its ends and its value take, so each reads exactly, and no more than six.

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
