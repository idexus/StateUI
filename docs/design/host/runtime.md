# The runtime

A runtime is the part of a host that turns the core's patches and cycles into
native views, and turns what the user does back into state. Every runtime has
the same elements, one job each, named alike in every language. The
toolkit-neutral elements are the host layer, `lib/StateUI/StateUI.Host` - the module
`StateUIHost`, which reaches the core through `@_spi(Host)` - and every host,
Swift in the application's process, uses them as they are. Its folders are
its parts; [the host layer](../../internals/host-layer.md) maps them.

## The layers

```text
  application              views, @State, handlers, engines
       |
       v
  StateUI core             state, keys, diffing, timing laws        lib/StateUI/Core/Sources
       |                   HostRender / HostPatch (typed)
       v
  host layer               CoreLink        PatchIntake
  StateUIHost             MountedTree     MountedElement
  lib/StateUI/StateUI.Host         Animator        StateChannels
                           DescribedMotion LayoutMotion
                           DisplayCycle    ProgramWrite
                           Pump            HandlerDispatch
       |
       v
  toolkit half             frame signal, each element's native half,
  one package per host     realizations, layout views, scrolling, gestures,
  (lib/StateUI/StateUI.AppKit,     focus, accessibility, windows and menus
  lib/StateUI/StateUI.UIKit,
  lib/StateUI/StateUI.Android,
  lib/StateUI/StateUI.WinUI,
  lib/StateUI/StateUI.GTK,
  lib/StateUI/StateUI.Web)
       |
       v
  native views
```

A host takes the typed patch. A native host links the core's dynamic library,
so one process holds one copy of StateUI's types; WebAssembly links no library
dynamically, so a Web build is one module holding the application, StateUI
and its host.

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
| | | a user's change carried onto its state and its event, a radio set (`MountedElement.reportUserChange`), a scroller's move (`reportScrolled`) | host layer |
| | | the native callback that hears the user | toolkit half |
| J | a journey's animations, run by the host | `Animator`, `Animation`, `AnimationTarget`; the laws are `HostMotionLaw` in the core | host layer |
| E | the frame engines and animations run on | `DisplayCycle`; the `FrameClock` protocol | host layer |
| | | the frame signal: the toolkit's display link | toolkit half |
| P | presenting what D describes, reporting the user into C | the layout arithmetic: `StackArithmetic`, `GridArithmetic`, `ZStackArithmetic`, `SingleChildArithmetic`, `ScrollArithmetic`, `MeasurementCache` | host layer |
| | | the layout views, scrolling, gestures, drawing, focus, accessibility, windows, menus | toolkit half |
| B | transport and process | `CoreLink`; `Registry` is the core's | host layer |
| | | `Pump`, the act performer (`HostActPerformer`); `HostRuntime` wires every part above | host layer |
| | | the doorbell's post, the acts' toolkit part (`ActToolkit`) | toolkit half |

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
    3  CoreLink.cycle(now:reducesMotion:)          engines and conversions run in the core;
                                                   StateChannels take the changes
    4  the elements the batch touches             each element's native setters once,
                                                   deepest first, each changed parent
                                                   arranged once, after its children;
                                                   finished animations answer their waiters
    5  the clock stays held while anything moves; it lets go only here
    6  a render, when the core needs one
```

A user's own change drains steps 2 to 5 at once, so the followers and
the engines move on the user's frame.

Step 4 visits the elements that present a state the cycle moved or hold a
property an animation moved - found by their state's number and their mount,
not by a walk - and the parents their moves ask to arrange, up through
elements with no view of their own; a parent whose child's `zIndex` moved
draws its children in order again. A frame costs what it touches, however
large the tree: a walk of every element on every frame, a layered one's
children compared each time, was most of a frame's work, and a tablet's
browser could not keep up.

The cycle's time never runs back. The display stamps each frame with the time
of its last refresh, and a turn between frames - a report, a handler, the
environment - drains on the runtime's own time, which is later. A frame
stamped before the last drain runs at that drain's time instead: an animation
advanced by the drain would otherwise step back on the frame after it, and
forward again on the next.

In step 4 a host only presents each element's moved values; what they ask
of the elements around it is decided once, for every host
(`MountedElement.presentFrame`): the element presents itself again; its
parent arranges again where a value that places it moved, or where it shows
no view of its own and is drawn by its parent's; and the window's chrome is
composed again where it shows what moved (`WindowChrome.follows`): a window's
frame, an arrangement's bar colours, and a page's title, bar, way back and
back button's words said from a state, which no render follows.

## One turn

The UI thread takes a turn whenever the core has work: a job on `MainActor`, a
cycle, a render or an act. On Apple it is taken after each pass of the main run
loop; on the Web as each call from the page ends, and the page is asked to call
again when work is left (`CoreLink.nextWake`); elsewhere the doorbell posts it.
The turn always runs in the same order.

```text
  Apple: the main run     the Web: a call      elsewhere: the doorbell posts
  loop's pass ends        from the page ends   one turn to the UI thread
    |                       |                    |
    v                       v                    v
  pump:  run the jobs  ->  an asked cycle  ->  render  ->  its cycle  ->  acts
                                                  |
                                                  v
                          PatchIntake.take(_:generation:apply:)
                            ProgramWrite marks the writes, handlers wait
                            the mounted tree applies the patch
                            a drift: refused, and render(baseline: 0) once
                            the generation is claimed only when it went in whole
```

The acts come last, so an act lands on the interface its handler just changed.

The cycle a render asks for runs in the same turn, once, before anything is
drawn: a layout engine's run of the views the render put in stands with them.
Left to the next frame, the toolkit drew the new views by a run worked out for
the old - each placed by position, so a view put in at the front stood where
the one now after it was, and the last stood in no place at all, drawn by its
own values. A cycle it wakes in turn waits for the frame, so a turn ends.

`Pump` is that turn, once for every runtime. A toolkit gives the runtime one
`HostPresenter`: what a render changed around the tree - the windows, their
pages, their chrome - what a frame's walk moved of the chrome, and the
performer of an act; the rest of a turn and a frame is the runtime's. A turn asked for while one
runs runs when it ends; the handlers a render created run and the turn goes
round again; the handlers waiting in `HandlerDispatch` run, a phase rendered
before what comes after it, and the turn goes round again; only then the acts.

## Probes

`STATEUI_PROBE=1` in a process's environment - on the Web, in the page's
address - times the runtime's stages (`HostProbe`) and writes, once a second
while it works, one line of each stage that ran: its milliseconds in that
second, its runs and its longest. The stages lie side by side, none inside
another: a native event's handlers (`events`), the core's jobs, a `render`,
its patch applied (`apply`), the windows and pages shown after it
(`windows`), the `animations`, the core's `cycle` - engines, a layout's run
- and what moved presented to the natives (`present`). The Web page shows
the line over itself beside its own counts (platforms/web/runtime.md,
probes). Unprobed, a stage costs one test of a static.

## The doorbell

Where the platform's loop is neither Apple's nor the browser's, a host says at
its start how a turn is posted onto its UI thread from any thread
(`CoreLink.postTurns`): WinUI through its relay, GTK through GLib, Android onto
its looper. The core posts one through it whenever work comes - a state written
or an act sent on the UI thread, a job queued from any thread, a handler's
resume or a post - on the thread the work came from; no thread of the host's
waits. One turn is posted until its drain begins. The turn itself is the
`Pump`'s.

## The turn on Apple

On Apple every source of work is a pass of the main run loop: a handler's
event, a resumed task on the main queue, a post's job, a frame. So AppKit and
UIKit ring nothing: `RunLoopTurns` watches the main run loop in every common
mode and, as each pass ends - before the loop sleeps, or as a run of it returns
- takes a turn where the core has work (`Pump.turnIfWanted`, the core's
`wantsTurn` or a handler waiting). The turn renders what the pass wrote before
the pass is over, ahead of Core Animation's commit, so a write is on the
screen in the frame of the pass that made it, and no thread of the host's own
ever waits on the core.

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

The toolkit-neutral elements live once, in the host layer, because every Swift host
would otherwise carry its own copy of the same arithmetic and rules: the
mounted tree and its patches, the animations, the state channels, the property
and layout animations, the display cycle's order, the one mark of a program's
write, a scroller's movement, the patch intake and the line to the core - and
the windows, the pages, the layout, drawing, text and input rules, the acts
and the environment's words, which [the host layer](../../internals/host-layer.md) maps
part by part. A toolkit gives the layer
each element's native half through `NativeElement`, its frame signal through
`FrameClock`, presents a turn and a frame through one `HostPresenter`, and
hands
`LayoutMotion` the views it places as `PlacedView`. The host layer's own suite
tests them on every platform it builds on, and `RuntimeArchitectureTests` holds
every Swift runtime to them: only `Animator` samples a timing law, only
`DisplayCycle` advances the animator and runs the core's cycle, only `Pump`
renders and takes the acts, only `CoreLink`
calls into the core, only `ProgramWrite` marks a write, and no runtime type is
an engine or a channel other than a state's. [Motion](motion.md) gives the
reasons of the animator, the state channels, the described motion and the layout
motion; [patches](patches.md) those of the patch intake and the program write;
[the mounted tree](tree.md) those of the tree and its native halves;
[layout](layout.md) those of the layout arithmetic.

## The mount's stack

The host layer makes and applies the tree by recursion - an element's patch
applied, then its children made or applied, each an element - so, as the
differ's walk does (core/identity-and-diffing.md, the walk's stack), it goes
down through small frames: `apply` takes the patch's own values in one step
(`received`), walks the children (`childrenApplied`, `arrange`, `mounted` -
loops, no closures held across them), and tells the native half in another
(`settled`), what crosses the children kept behind one reference
(`Applying`). A WebAssembly Gallery in a debug build overflowed a tablet
browser's stack - far less than a desktop's - before its first frame, the
differ first and the mount next; `MountStackTests` holds a level under eight
kilobytes. A WebAssembly start that fails takes the loading screen away, so
its reason stands on the page rather than a load with no end.

## After a layout pass

What a host must do once the layout pass under way is over - on GTK a field's
caret the toolkit's focus undid, a list's changes held while its rows bind and
the entries it shows, and a split view's first room; on WinUI a split view's
first room - waits in one queue
(`HostRuntime.afterLayout`): it runs once the pass is over, in the order it
came, and work that comes while it runs waits for the next. The host asks once
to be told a pass is over and then takes a turn: GTK at the idle after its
layout and paint, WinUI in the next turn it posts, as WinUI lays out before its
queue's next message. Android's list holds its changes in its relay until the
recycler stops laying out. A scroller's offset written before its first layout
is not this queue's: it waits in the scroller (`WrittenScrollOffset`), which
applies it in its own arrange, before it draws and only once it has a size.

## Where a view stands

An element whose frame the tree reads - a state its frame drives, or a
handler of its changes - says where it stands on the display's next frame
after anything was laid out or moved: its place in its parent onto the
state, the whole report to its handler, and nothing where the report is the
one it last said (`MountedElement.reportFrame`). The runtime's
`FrameFollowers` keeps the frames coming while a scroller moves or has
something to say, or a frame read may have moved, and on each frame lets the
scrollers say what they did, then the elements where they stand, each in the
order its view was made, as one user's transaction. A list's view moving
says it too (items.md, `The view moving`). A host says only what its
toolkit knows: the numbers of the place. It says nothing while the view
stands in no window or before a layout placed it - a view that joins a shown
page meets a display frame before the layout pass that places it - so the
first report a handler hears is where the view is laid out, never zeros. A
view is laid out once StateUI's layout placed it or its toolkit gave it a
size, the same on every native host (`MountedElement.isLaidOut`); the Web
asks the browser whether the element has a box.
The Web, as each call from the page ends and before the browser draws, lets
what was laid out say it at once (`FrameFollowers.reportLaidOut`), so a
size worked out from a frame is drawn in the frame that measured it; a
scroller still says what it did on the display's frame. AppKit does the
same in each room's layout pass - the window's content, a split view's
pane - laying the page out, letting it say, and laying it out again where
anything did (`layOutReporting`): a split view sliding its sidebar lays out
only its panes, and a report left to the display's next frame stood the
page's content in the last frame's width every other frame. GTK lets it say
in its frame clock's layout phase, after the window's own layout, and the
clock lays out again what that changed before it paints.

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

## A disabled branch

A view the tree disables keeps its place and still stands in the way of a
press, but answers none; on a layout the whole branch in it answers none
(`MountedElement.isEffectivelyEnabled`). The rule is the host layer's, once:
`hear` drops what the user does to a view in a disabled branch - only a drag
it began still ends there - and a view's `isEnabled` reaches its control as
`presented(_:)` gives it, false wherever a view holding it is disabled. When
a layout's `isEnabled` changes, every element in it presents its own again
(`enablementTurned`), so a native control in the branch is disabled and
enabled with it. A host reads a view's members through `presented`, never
the element's own value. A bar's action and a menu's item stand in no view,
so a host reads `isEffectivelyEnabled` for them: one declared in a disabled
branch is out of reach with it, and comes back as the branch is enabled.

## A press dragged

A host whose toolkit tells a press and its moves, and no drag of its own,
tells a drag by one rule (`DragRecognition`): the press is a drag once it
has moved MORE than the platform's distance from where it went down - along
either axis where the platform measures a rectangle, Windows and GTK, or any
way where it measures a radius, Android; the browser gives none, so the Web
takes a radius of its own - four points for a mouse or a pen, ten for a
finger ([its input](../platforms/web/input.md#a-press-dragged-and-a-pinch)).
It starts there, at nothing, and then each move is the drag's, measured from
where the press went down, until the press lets go and it completes, or the
platform takes the press away and it is cancelled. A press that never became
a drag ends with nothing. A platform's distance is taken in DIPs; the toolkit
holds the pointer once the press is a drag, which the host asks for as the
rule says so.

## The hand over a layout

A layout engine a hand moves hears the hand itself (`Hearing.hand`, its
`handAxis`): a press dragged - a finger or a pointer - a trackpad's two
fingers and a wheel, each as the platform tells it, said as `HeardInput.hand`
or `.wheel`. `HandReading` makes them one stream of the element's
`handMoved` - a beginning, each move of what is under the hand, and a lift
with its speed - alike on every host. Where the platform tells no speed at
the lift, the moves of its last tenth of a second say it. A wheel tells no
beginning and no lift: its first notch opens a gesture, and a frame finding
it still for 150 ms lets it go with no throw (the runtime's frames pace every
open wheel, and hold the clock while one is open). A trackpad that reaches a
host as a wheel - a page's, with the system's momentum in it; Windows'
through a virtual machine - says its lift by its pace: its steps of the last
four frames summed over that window, as steps come late, glued together or
uneven, and one alone says nothing. Three steps in a row each slower than
the last, each of eight points at least, are the momentum - a slow hand
makes none, its steps of a few points slowing and quickening by chance, and
a pause lets it go - so the wheel is let go there with the speed its moves
say. The momentum after it is swallowed until a step against it, the wheel
half as fast again as the momentum at its slowest with a step of eight
points at least - a hand pushing again - or a gap of more than six frames, a
hand that stopped it and moves again. A wheel the platform says turns notch by
notch is no stream: it is said as notches (`HeardInput.notch`), a fine
wheel's parts adding up to whole ones (`HandReading.notches`), each a step
of the run to the next target (`handStepped`). What the hand says is kept
for the next frame and said at its start, before the cycle - its moves since
the last frame as one (`HandPace`): a toolkit telling the hand faster than
the display draws, 120 times a second or in a burst a busy thread held back,
moves the run once a frame. A layout claims a hand
whose first move is more along its axis than across it; the rest is left to
whatever holds the layout, a page's scroller. What the hand does to the run -
the phase moving with it, a throw to the target nearest its end - is the
core's (views/layout-engine.md, the hand).

A layout whose views the hand takes by themselves (`itemDrag`) gives the
hand one of three owners, by one rule every host shares: a first move along
its axis is the run's; a first move across it is the view's under the press
where views are taken `.across`, else the page's; and a press standing still
`HandReading.hold` - 500 ms, the long press the platforms share closely
enough - is the view's where they are taken `.held`, then whichever way it
goes. A host says where a press went down (`HeardInput.hand`'s `point`) and
every move and lift as it does for the run, and its end always - a press that
held a view and never moved still lets it go; it decides nothing more. The
hold is found by the frames, since nothing moves: a press waiting for it holds
the clock (`HandReading.wantsFrames`), as an open wheel does. The view's hand
is said as the element's `itemMoved` - where it is in the layout, from the
press's point and every move since, its speed at the lift as the run's is
read, and how long it has stood still - told again each hold it stands, so
an application can turn a board under an icon held at its edge.

## Two fingers over a layout

A layout engine that `magnifies` or `rotates` hears two fingers itself
(`Hearing.pinches`, `Hearing.rotations`): a pinch and a rotation, each as
the platform tells it - its own gesture where the toolkit has one, two
pointers where it tells only pointers (`TwoFingers`: how far apart they
stand and which way the line between them turns, clockwise in a view whose
y grows down, the short way round). `PinchReading` makes the two one stream
of the element's `pinchMoved`: begun with the first, ended with the last -
a move with no beginning heard begins it, a cancel of the last cancels it -
each move a scale and degrees since the last, said at the next frame's
start as one, and as the fingers lift their speed, read from the last
tenth of a second: the scale's logarithm across, the degrees down.

The rule for gestures at once is one, every host's: the hand and the two
fingers move together. While two fingers spread and turn, the hand - a pan,
a scroll - goes on with their middle (`PointerMiddle`): each finger's step
moves it by that step over how many fingers are down, and a finger landing
or lifting moves it nowhere, so fingers turning about their middle hold the
run still and moving together carry it. A toolkit whose pan already follows
the fingers' middle (UIKit's) is that rule; a host reading pointers one by
one reads them so. A view held by itself keeps the hand: the fingers say
nothing while it does.

## A wheel turned as a pinch

A platform that hears no gesture of a trackpad's pinch for an application
tells it as a wheel turned with Control - Windows does, a browser does, and
a Mac's trackpad reaches a Parallels guest of Windows so - and a mouse's
wheel with Control zooms on the Windows and GNOME desktops. Where a view
hears a pinch, a host tells such a turn as `HeardInput.wheelPinch`, its
scale in the platform's units - a notch a tenth (`WheelPinch.notch`), a
browser's pixels as the browser makes them (`exp(-down / 100)`) - and the
host layer makes it a pinch (`WheelPinch`): begun with its first turn, each
turn a step, and let go by the frames once the wheel has stood still
`HandReading.pause`, as a wheel tells no lift. A Mac takes no Control and
wheel for a pinch: there Control and the wheel zoom the whole screen.

## Two fingers from one pointer

A mouse turns and spreads what two fingers do: a press dragged with ⌥/Alt
over a view that hears a pinch or a rotation is TWO FINGERS, the press and its
mirror about the view's middle, as the iOS Simulator makes them - round the
middle a turn, toward or away from it a spread, both at once. A host tells
the press with Alt as `HeardInput.mirrored(phase, at:, middle:)` - where the
press stands and the view's middle, in its points - and the host layer reads
the two (`MirroredFingers`, by `TwoFingers`) and tells their steps as a
pinch's and a rotation's, so they go on as the one stream two fingers are
(`PinchReading`): thrown on as they lift, the hand standing still, as their
middle does. The press is the fingers' alone - a layout's hand leaves it, a
press without Alt goes on as before. Where no trackpad tells a rotation -
any mouse, and Chrome and Firefox on a Mac, which tell a trackpad's pinch as
a wheel and its turn as nothing - this is the rotation's road. Each host
reads Alt as its toolkit holds it: AppKit's event's ⌥ (a recognizer a pan
waits on), GTK's controller state (`GDK_ALT_MASK`, a drag of its own claimed
or denied at its start), WinUI's pointer's key modifiers (the relay's
`mirrored`), the Web's pointer event's `altKey`.

## A swipe

A host whose toolkit tells it a press and how far it has moved, and no swipe,
tells a swipe by one rule (`SwipeDirection.swiped`): the press went the one
way it moved most - across when it moved at least as far across as down - if
that movement reaches the view's threshold and the view listens for that way.
A way it does not listen for is no swipe, even where the press also moved far
along the other axis: the dominant way decides, never a second one.

## A drag between views

A view offers a drag where `canDrag` holds, carrying its `dragText` - empty
where it gives none - and takes one where `allowsDrop` holds
(`DragAndDrop`): what travels is fixed before the drag starts, as a native
drag needs its payload at once. A toolkit tells a drag over a view in its
own way - again and again while it moves, a leave after a drop on some, a
leave for each child on others - so the element hears it through one rule
(`DropTarget`): over once as a drag comes, left as it goes without being
let go and never after a drop, dropped with its words as it is let go. The
view dragged hears its drag start, and end once wherever it ended. A host
that realizes it declares `everyElementDragsAndDrops`.

## Files dropped on a view

A view takes files dragged from the system where `droppedFileTypes` is
written: the kinds it lists, any file where it lists none (`DragAndDrop`).
A toolkit seldom says a dragged file's name before the drop, so a drag of
files is taken over any view taking files, and the drop decides
(`DragAndDrop.taken`): the files of its kinds - by their names' extensions -
are heard, in order; a drop holding none of them is heard by nobody. A
dropped file is a `ChosenFile`, read and launched as one opened, its address
the platform's own. A host that realizes it declares
`everyElementTakesDroppedFiles`.

## The environment

What a host reads of the machine it stands on is told to the core the same
way on every host: the locale as eight words - language, region, name, time
zone, a 24-hour clock, the week's first day from Sunday's 0, metric measures,
a language written right to left - the network as its access and a set of
bits for its connections, a battery as present or not, charging, on mains
or full, and a screen as landscape where it stands at least as wide as it is
tall, turned by quarters from its natural orientation - none on one that
turns with nothing. When any of it changes, one step
follows on every host (`HostRuntime.environmentChanged`): the core is told
what stands now, the tree follows the language's direction, and one turn
renders what it all changed. A report that repeats what stands - and
platforms repeat themselves often, a network monitor several times a frame -
changes nothing and takes no turn: a turn between frames would move
whatever moves once more.

## The theme in force

An application may hold a theme of its own (`application.colorScheme`), and
its act shows every window in it with the toolkit's own call. The theme the
core resolves colour pairs against is then the theme in force, the same on
every host (`HostThemes`): the application's while it holds one, the
system's while it follows the system. A host reports the system's theme as
its toolkit tells it, and the host layer passes on the theme in force - so a
toolkit that tells the system's alone, a browser's media query, reports the
application's all the same, and one that tells its own effective look agrees
with it.

## The application's phase

A toolkit tells what each window does - whether it is minimized, and whether
it is activated - and whether the whole application is hidden, and every host
tells it on alike (`ApplicationLifecycle`, `HostRuntime.windowStateChanged`);
whether a scene hides a window is the host layer's (`hidesWhenInactive`).
What it tells settles a turn later, with whatever else it tells in the same
one: a toolkit tells a window deactivated before it tells another activated,
and the two are one move, in which the application stays in use.

- The application is in use while one of its windows is activated, seen
  nowhere while it is hidden or none of its windows stands on the screen,
  else showing behind another application.
- The scene in front is the one whose window was activated last. Only
  another window's activation moves it; the application going behind another
  moves it nowhere. Of the windows staying when one goes, the one activated
  last is the one the user comes back to (`activatedLast`), for a host whose
  toolkit leaves that choice to it.
- A scene is activated while one of its windows is, stopped while every
  window of it is off the screen - the application hidden among the causes -
  else deactivated.
- A window is stopped while it is off the screen - minimized, hidden with
  the application, or hidden by its scene - else activated or deactivated.
  One that stands again hears first that it resumed.
- A window that hides while another scene is in front
  (`hidesWhenInactive`) stands hidden while one is, and none hides before a
  scene first came to the front. A window that floats (`floatsOnTop`)
  floats while the application is in front, and sinks with it.

The core hears the phase, then each scene and window what moved for it -
what leaves first, then what is activated - each rendered before the next,
and the windows stand again where the scene in front or the floating moved.
They are heard in their turn, as a window's being made is, so a toolkit
telling a state in the middle of one - a window activated as the host shows
it - waits for it to end. What stands already tells nothing: a lifecycle is
a state, not a count of the toolkit's callbacks. As the application ends,
every window hears that it is going.

## A window the user closes

A window the user closes hears that it is going, then its scene hears that
it closed, carrying the window's key - each rendered before the next
(`HostRuntime.userClosed`). The scene forgets the window and its session, and
ends with its last. A window the tree closes tells nothing: the tree already
knows.

## Acts

An act the application calls is answered on every host the same way: with
a reply carrying its values, or a failure carrying the reason - a caller
waiting on it throws that, and one nobody waits on goes to the host's log - so
no caller waits on an act nobody performs. An act aimed at a view names it by
its first argument, the element's own id or its number; one naming none, or
none on screen, fails with that reason (`MountedTree.aimed`). One performer
does this for every host (`HostActPerformer`): it reads each act, keeps the
questions in line, answers and fails; a host gives it its toolkit's part
(`ActToolkit`) - its name and its log, the clock and the zones, a question
shown, a word to the screen reader, the theme shown, the focus and the
on-screen keyboard, a value kept, the acts its own controls answer and those
the application registered - and nothing more.

## An application's own acts

An act the application performs itself on its host - one no control stands
behind, or one aimed at an element of its own - is registered by its member
and performed the same way on every host (`InteropActs`): handed the values
its contract declares, an aimed one also the control of the element its first
argument names, and answered once it returns, or failed with why - a call
carrying other values than its act declares, an element the host shows
otherwise, or what the performer threw. What a host adds is its toolkit's:
the control it hands an aimed act.

## Questions for the user

A question - an alert, a confirmation, a choice of actions, a prompt - is
read from its act the same way on every host (`HostQuestion`): its title and
message, the accepting caption, the cancelling one (a choice's only where it
names one) - the core sends the library's own words in the system's language
where the application names none, so "OK" and "Cancel" here stand only for an
act that came without them - a choice's dangerous action and its others, a prompt's placeholder,
bound, purpose and starting words. It answers as its kind does: a
confirmation yes or no, a choice or a prompt its words where the user
accepted - a prompt's cut to its bound, by characters - and nothing where
not, an alert nothing. A question the toolkit could not show - another
dialog standing where it would - fails its call with the toolkit's reason:
the toolkit answers a `Result`, as a file dialog does, and a failure is never
read as the user saying no. Questions show one at a
time in the order asked, each under a ticket of its own across the process
(`QuestionQueue`), so an answer after its runtime has gone answers nothing
of another's.

## Files

A file dialog is read from its act alike on every host (`HostFileDialog`):
one file to open, several, or a place to save, the kinds it offers, a
save's contents and its name. A save's name ends in an extension of its
kinds: where it ends in none, the first kind's first is added - unless it
is empty, which the platform names. A dialog that filters by extension
alone shows every kind's, in order, each once. A file dialog waits its turn
among the questions, one showing at a time, so a question never stands
over a dialog the user is still in, or under one. A host performing files
hands its `FileToolkit` to its performer beside its `ActToolkit`, and
declares `HostActs.files`; a host without one fails every act for files by
name. A file read and a launch answer when the platform does, never in the
turn that asked.

## Starting

Every host starts in one order (`HostRuntime.start`): what it realizes; the
environment it stands on - the device, the display, the theme, the
application's facts; the values the platform kept, read only once the device
is told, as reading their keys makes the application, which is made knowing
the device; the language's direction, so the tree stands in it from its first
window; the windows - the scenes kept, or the platform's first window; then
the turns - a doorbell, the run loop's, the page's entries. A host gives each
step in its toolkit's terms, and a later start in the same process - Android's
next activity, WinUI's next launch - reads no kept values again.

Before that order, a host whose UI thread is not Apple's main thread - on
Android, GTK, WinUI and the Web - claims the thread it starts on as the UI
thread (`CoreLink.claimUIThread`).

## Kept values

Every host keeps a value as its words, by one rule (`KeptWord`): a value is
kept as the words its key's kind reads back, and a value of another kind is
not kept. A key the application does not list still saves, as its value's
own kind - true or false, a number, words - which its key's kind reads back
once it is listed, as the application's session promises. The words stand in
the platform's own store where it has one - the preferences on a Mac, on iOS
and on Android.

A host whose platform keeps no store an application can use keeps them in a
file of its own, and one codec says what the file holds (`KeptValuesText`): a
line a key, its name and its words apart by a tab - a tab, a line's end and a
backslash in either escaped - the keys in order, so the same values write the
same file. Where the file stands and how it is read and written is the
host's. The Web keeps the codec's text whole, under one key, in the browser's
storage for its site.

## The platform's first window

Every platform window comes through one road (`HostRuntime.connectWindow`):
the platform's first - the window launch opens takes it - a new one of no
kind, or one it kept. A host connects its first window as it starts, a kept
one or a new one, so the window launch opens is the platform's first and
*File ▸ New* makes one more (core/scenes.md, What the platform hands over). A
host whose windows come after its start - iOS connects its scenes then -
holds its turns until the first comes (`Pump.waitsForFirstWindow`), so the
scene a kept window opens is built with what it kept, never its default first.

## Kept scenes

A host whose platform restores no windows keeps the application's scenes for
its next start itself (`SceneKeeper`), in a store of its own whose text one
codec writes (`KeptScenes`): a line for each scene, then a line for each of
its kept values - by key, in order, the value's kind a letter before its
words - then a line for each of its windows, with its kind and the text of
the value it was opened for where it has them. At the start each window kept
connects before the first render, as its kind for its value, with its
scene's values, which land where the scene opens with it; a window of a kind
no scene declares now is kept no more, and where none comes back the window
launch opens comes. The scenes are kept again whenever the text they write
changes - a scene's value the application keeps, a window opened or closed,
a scene ended - but not once no scene stands: the last scene's end is the
application's, and the next start finds the scenes as they stood before it.

## Restored windows

A platform that restores windows itself - AppKit's restorable state, iOS's
scene sessions - hands each back with what the window kept of itself, its
record (`WindowRecord`): the window's identity, its kind, the text of its
value and the values its scene keeps - every window carries them, since any
may be the one that opens its scene again. One text holds the record, written
by the host layer for every such platform, so a record reads back the same on
each.

Each window restored comes in the moment it comes, as its kind for its value
(`RestoredWindows.accept`): its scene's values land where the scene opens
with it, before its first build, and the host keeps them for the scene
(`SceneValues`, which mirrors the core: a scene standing keeps its own). A
window of a kind no scene declares now, or whose value no longer reads, is
refused, and the host lets it go. A window accepted waits for the window
element it opened, which takes it by its kind and value
(`RestoredWindows.take`) - a kind is one scene's, so it names the scene.

## Typed words

A field holds its words in its case: the program's are written so, and what
a user types is turned into it, then cut past the field's bound to its first
characters that fit, as the contract counts characters (`InputWords.held`,
`InputWords.cut`), and written back as the program's - but not while an
input method still composes them: changed under it, the composition is lost,
so they stand as typed until it commits them (`composing`), which each host
reads from its toolkit's marked text or composing span; a toolkit that asks
before it inserts takes what goes in, in the case and within the bound, in
the same terms (`InputWords.fitting`). A caret and a selection the tree
puts, in characters, reach a toolkit counting UTF-16 units as the units those characters take
(`InputWords.utf16Selection`), so a character outside the basic plane - an
emoji - is never split. A picker is given its choices where they changed, and
its choice only where the tree changed it or the choices (`PickerChoices`):
the user's own choice is never argued with.

## What typing is given

What a field's keyboard and the platform's checking of its words do is read
once from what the tree says (`InputTraits`): spell checking, prediction -
correction goes with it - and the input purpose, which picks the keys a
screen keyboard offers and where capitals go. Plain words are taken as typed:
no capitals, no checking, no correction, no prediction - a login, a code a
user types or a scanner enters. An address takes no capitals; text starts
its sentences in them; the default leaves the platform its own. Each host
tells its toolkit these in its own terms - a keyboard type, input flags, the
text checking a desktop does as the user types.

## A value in a range

A value a control holds inside a range - a slider's, a stepper's, a progress
bar's - follows one arithmetic on every host (`ValueArithmetic`): the range's
ends stand in order whichever the tree gave first; a step that does not move
is 1; a share of work past an end stands at that end, one that is no number
at the start; a slider's key moves a hundredth of its range and a page a
tenth; a stepped number is written with as many decimals as its step,
its ends and its value take, so each reads exactly, and no more than six;
and a stepper's step moves only away from the range's end it stands at
(`ValueArithmetic.stepsWay`), its button of that way standing disabled where
the host draws the buttons itself.

Such a control is written, as its value and its ends apply, by one rule
(`ElementValues.written`): the tree's value where the tree changed the value
or an end, else the value the control shows, so a hand on the thumb or the
buttons is never argued with. A range that moves takes the tree's value
again: the control stood clamped at the old range's end - a state's value
outside it, or one travelling to the value written with the range - and a
range widened over that value shows it rather than the end it stood at.

A stepper shows its steps alone (`ElementValues.shownStep`,
`ValueArithmetic.stepped`). Its presentation is discrete; the journey a state
carries its value on is not. So it shows a step of where its value is headed
- the destination and every step from it within the range - the nearest to
where the journey stands, between there and the destination: never a value
between two steps, one behind where the journey set out, or one past where it
lands; at rest, its value itself. The destination comes with the journey
(`ElementValues.destination`).

## A day and a time

A picker holds a day and a time by one arithmetic on every host
(`CalendarArithmetic`): a day not in the Gregorian calendar - February 31st,
a thirteenth month - is refused, and the picker goes on showing the day it
had; a day past the range stands at its end, the range's ends in order
whichever the tree gave first; and a time is its hours, minutes and seconds
added up from midnight around the day, so 25:99 shows as 02:39.

What a picker shows - its list, its calendar, its clock - is opened and
closed by the program and by the user, and only the user's are heard
(`PickerOpening`): the program asks, and the toolkit's next opening or
closing is the echo of that request; the user's closing of what the program
opened is the user's, and heard.

## The log

What a host says for whoever reads its log rather than its screen is one
line a message, begun by `StateUI` and the host's name (`HostLog`), written
to standard error, which nothing buffers, so a line stands in the log before
whatever went wrong next; a platform whose log is its own - Android's - hands
the lines there.

## Core link

A runtime calls the running core through `CoreLink` alone: a render, a cycle,
an event, an act call and its answer, a user's report, the application's and
the scene's reports, the kept values and the way a turn is posted. The line is the
typed `HostBoundary` SPI. The lane codecs - a journey read from its
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
