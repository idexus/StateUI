# Runs: an event that comes again

A handler with no `await` is one step: it runs whole inside its event, and a
second event finds it over. A handler that awaits is a run, which an event can
find still under way - a second click on Save, a newer query, the page a run
belongs to already gone. What then happens is the handler's to say, and
nothing else may change once a run is no longer wanted.

## The runs of a handler

An event's handlers keep their runs under the event's id in an
`EventRegistration`, each handler its `RunOwner`: who started a run. The id
survives renders, so a run started by one render's closure is still its
owner's when the next render writes the closure again. A run is started in a
`RunSlot` - a shared gate's, or the owner's own where the handler was given
a policy alone - which holds the runs under way and waiting, and decides, by
the policy, what an event that comes while one is under way does.
`RunSlot.start` makes every run's task at once - one that starts, waits in the
slot for its turn, or is let go - so a run that never starts still ends and
nothing keeps its handler.

A composed view's own event - a motion layout's rest and dismissal, a
gallery's position and activation - keeps an `EventRegistration` of its own in
a state, so
each of its handlers given a policy alone has a gate of its own too, as an
element's do: one held under `.ignoreWhileRunning` keeps no other from
running. A dismissal starts only the handlers whose way the view passed, each
through its own. Every render keeps the registration to the handlers written
(`keep`), so one no longer written ends its runs then, with no event to come,
and the view leaving ends them all, however many it wrote last. An event told
after the frame - a rest, a dismissal - starts through the owners kept when it
came (`starting`), each handler with that event's own values, and starts
nothing for an owner no longer kept by then: a render that dropped the handler,
or the view gone, between the frame and the start. A gallery's tap presses the
card once and then starts every activation handler, in the order written: a
press each, each waiting its own, would let them resume in any order.

## A gate

An awaiting handler passes through a gate, whose policy says what an event
does while a run is under way through it:

```text
  .ignoreWhileRunning   the event is let go - a save, an order, a sign-in
  .cancelPrevious       every run under way is superseded, then this one
                        starts - a search, a movement to a new place
  .waitForPrevious      the event waits; when no run is under way, the oldest
                        waiting one runs - one at a time, in the order they came
  .runConcurrently      nothing is held back: this run starts beside the ones
                        under way
```

A gate is a handler's own or shared, and the argument's label says which. A
`GatePolicy` given alone - `.onClicked(policy: .ignoreWhileRunning)`, or
`policy: .cancelPrevious` after the event's own arguments, as in
`.onChanged(query, policy: .cancelPrevious)` - gives the handler a gate of its
own: its runs stand in its owner's slot, so two buttons written with
`.ignoreWhileRunning` never hold each other back, and a policy has no `isBusy`
to read. A `Gate` kept in a state or a model, always given as `gate:`, is
shared by every handler and task written with it, from one control or several
- a save and a delete of one document - and its `isBusy`, a state, says
whether a run is under way or waits through it. Every awaiting modifier has
both overloads; inside the library a handler keeps `Gating`, `.own` or
`.shared`, and its case says where a run goes - no cast decides it at run
time. The policies are a struct's static members over an internal kind, so
`.runConcurrently` names one thing given alone or to `Gate(_:)`. An element
leaving supersedes its owners' runs alone, so behind a shared gate the
others' runs stand. Every run is numbered as it begins
(`HandlerRun.number`; `begun`, how many have) and carries its origin: the
number of the run under way as it began - the one whose task started it, a
`Task(gate:)` inside a handler - or its own where none was, so a run's origin
is the first of the runs it descends from. The runs standing are known by
number and origin, so a test waits on the runs whose origin began after a
mark it took (`HostBoundary.runsUnderWay(since:)`) and on none descending
from a run begun before, however late those began: a service the page began
runs on, and the work it starts while an act runs is the service's, not the
act's. A handler the host begins - an event's, or one a render's walk found -
starts outside every run (`Renderer.start`, `Renderer.run`): the task the
host was called from is the platform's or a test's, never the handler's
parent. So a test acting from a task through a gate still waits on the
handlers its act raised, and a run superseded around the call refuses nothing
they write.

The policy is written `policy:`, as a shared gate is `gate:`, after the
event's own arguments, which keep the step overload's spelling and its
defaults: `.onClicked(policy: .ignoreWhileRunning)`,
`.onEndReached(within: 5, policy: .ignoreWhileRunning)`,
`.onSwiped(directions: [.left], policy: .cancelPrevious)`. An argument that may
be left out stands before `policy:` with its default, so each event is heard
three ways - plainly, with a policy, through a gate - and never two ways with
a policy. `ModifierShapeTests` holds it: no policy stands unlabeled, and an
event has as many policy forms as plain ones and gate ones.

There is no default. Each event modifier comes as a step, `() throws ->
Void`, which Swift picks for a closure with no `await`, and the same with a
policy or a `gate:`, for a handler that awaits; an awaiting closure with
neither meets only the step, and does not compile. `.onCreated` and `.onDestroying` take no
gate, as each comes once. The compiler asks the question where there is one, and only
there.

`RunSlot.underWay` counts the runs of every slot from the moment a slot takes
one - started, or waiting its turn - to its end: what a test waits on for the
handlers' work to end, rather than a length of time, and the tally's `runs`
(diagnostics.md).

## A step

A policy or a gate is written only where a body awaits, in the library as in
an application (`GateSourceTests` reads `.runConcurrently` given before a
body). A step is written with none and kept with
none: a modifier's step overload goes down by step roads to the handler's
storage - `Handler(step:)`, `ValueHandler(step:)`, a watch's own - and never
through its gated twin with `.runConcurrently`. The overloads mirror each
other, each naming the event it hears, which is where the matrix's pages read
a modifier's name from; what they would share beyond a line or two stands
once beside them - `.onKeyPressed`'s keys, `.onVisualStateChanged`'s states, a
frame's last answer. A composed control keeps the author's handler as a
`ValueHandler` until an element it makes hears the event.

The step initializers are where a step meets its runtime: it runs through a
`.runConcurrently` gate of its own and never suspends. It takes no road of its own at
run time: an event dispatched to a step costs a couple of microseconds, so
even a drag's 120 events a second spend a fraction of a millisecond.

## Work started from code

Work a model starts from its own code - an autosave, a refresh a timer asks
for - passes a shared gate through `Task(gate:)`, as a handler written with
that gate would: the policy holds for it, it makes the gate busy, and it holds
back, or is held back by, the events through the same gate. The task it
returns is the run's own, the one `RunSlot.start` makes for every run:
awaiting its `value` waits for the work's end, cancelling it supersedes the
run as a later event would - a run still waiting its turn leaves the queue at
once, through a job on the UI thread - and a task the gate lets go ends at
once, its work not run. Its owner is the gate's own `RunOwner`, which nothing orphans, so no
element leaving ends the run; started inside a handler, it runs under a
`HandlerRun` of its own, not the handler's, descending from it: its origin
is the handler's. A policy is no gate for a task -
it has no element to keep its runs - so `Task(gate:)` takes a `Gate`
alone.

## A superseded run

A run is superseded by `.cancelPrevious` or by its task's cancellation, and
orphaned - superseded the same way - when its element stops handling the event
or leaves the tree; an orphaned run still waiting its turn never starts, and
its task ends. Its task
is cancelled, so `Task.sleep` and whatever else checks cancellation ends it,
and a superseded run ending in `CancellationError` is not reported; another
error it ends in is refused, as the rest of what it asks of the host is. A run
superseded in its first step - before `RunSlot.start` has its task in hand: a
task started through the same `.cancelPrevious` gate inside it, or its own
render taking its element out - is cancelled as the task comes to hand. An element
leaving cancels in one order every time - its events' runs by the events'
names, then what its walk runs in the order begun - so what a cancellation
handler does comes in that order too.

From then on it changes nothing. Every write of a state, every part of a
journey (`move`, `stop`, `snap`, its value, velocity and law), every post and
every act made by the run, or by a task under it, is refused and said once; an
act it awaits fails as `CancellationError`. A post is refused as it is posted;
its job belongs to no run, so what was admitted lands whoever posted beside it.

The run is read through a task-local, `HandlerRun.current`, which the tasks
under a run inherit. A write reads an atomic count of the superseded runs still
alive first, and the task-local only while that count is not nought - a
nanosecond a write in the ordinary case. A superseded run counts until it is
freed, not until its body ends: a task it started holds it, and is refused
however long it outlives the body, whatever other runs are under way.

The refusal stands for every state, a model's the page does not own
included: a page left never writes on through a model. What must outlive its
element goes to a detached task, which inherits no run - the refusal says so,
naming what it refused, and the handbook teaches it (interface/concurrency.md,
Work that outlives its element).

## The library's own tasks

A task the library starts for itself - a ticker's loop, a sampling's late
reading, a post's job, the delivery of raised events, a handler a render
queued, a cancelled waiting run's leaving the queue, the inspector's pace and
its notice of a complaint - starts with no run
around it (`libraryTask` clears `HandlerRun.current`), so it belongs to no run.
Started inside a handler, it would inherit that run and be refused once the
run is superseded: a ticker started by a run a second press cancelled would
tick and change nothing.

## A write built on a value gone

A run that reads a state, awaits, and writes it from what it read loses
whatever another wrote while it waited - `let old = count`, an `await`, `count
= old + 1`. Built for debugging, StateUI says so: a run keeps the stamp of each
state it reads, and a write of that state by the run compares it with the
stamp now. On the UI thread nothing else writes inside one synchronous stretch,
so a stamp that moved means the run waited and another wrote meanwhile - the
lost update itself, said once for that state, never a false alarm. A run that
reads the state again after its `await` builds on what it is, and is silent.
Every platform reads it alike: where a run suspends is invisible on Apple,
whose main queue has no hook, so the detector asks what changed rather than
where the run stopped.

## What a walk runs

`.onChanged`, `.onVisualStateChanged` and `.onCreated` run what a render's walk
found. Each starts its runs under an owner the element's `RunSlots` keep by
registration: a watch's place and value type, a listener's place and state
filter, or a created handler's place. Every render keeps only the registrations
still written, so removing one or changing a watch's type supersedes its runs
without another event. A retained registration keeps its owner and gate work.
An owner that leaves is retired: queued delivery cannot start it again.
An element leaving supersedes all of its owners. `.onCreated` runs once; its
runs belong to that registration's lifetime. `.onDestroying` runs as its element
leaves, a farewell, with no runs of its own: it goes to its end.

A subscription to a host event is an owner, and `cancel()` supersedes its
runs. A control the library composes that hears an author's handler inside its
own run - `GalleryView`'s position - starts that handler under an owner of its
own, through the author's gate.

## An element hears the host

`.onHostEvent` is a subscription that belongs to its element. Each one a
render writes is kept by the element's `RunSlots` at its place among them: the
first render that writes a place subscribes once (`HostEventRelay`), and each
later render hands the relay its new handler, so a raise runs with what the
last render captured, never a closure a build ago. A place that names another
event is subscribed afresh, one no longer written is cancelled, and the element
leaving cancels them all as it orphans its runs - so a view hears what the
host raises exactly while it stands, and nothing is cancelled by hand. The
handler reads the raise as `HostEvents.on` does: one decoding of the values
for both (`HostEvents.heard`).
