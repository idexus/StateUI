# Runs: an event that comes again

A handler with no `await` is one step: it runs whole inside its event, and a
second event finds it over. A handler that awaits is a run, which an event can
find still under way - a second click on Save, a newer query, the page a run
belongs to already gone. What then happens is the handler's to say, and
nothing else may change once a run is no longer wanted.

## The runs of a handler

Every handler an element writes for an event keeps its runs in a `RunSlot`,
and an event's handlers keep theirs in an `EventRegistration` under the
event's id. The id survives renders, so a run started by one render's closure
is still the slot's when the next render writes the closure again. Two
handlers of one event keep two slots: each runs by its own word, and neither
waits for the other.

An awaiting handler says, in a `RepeatedEvent`, what its event does when it
comes again while a run is under way:

```text
  .ignoreWhileRunning   the event is let go - a save, an order, a sign-in
  .cancelPrevious       every run under way is superseded, then this one
                        starts - a search, a movement to a new place
  .waitForPrevious      the event waits; when no run is under way, the oldest
                        waiting one runs - one at a time, in the order they came
  .overlap              this run starts beside the ones under way
```

There is no default. Each event modifier comes three ways: a step, `() throws
-> Void`, which Swift picks for a closure with no `await`; the same with a
`RepeatedEvent` first, for a handler that awaits; and an awaiting handler with
no word, unavailable, whose message says what to write. The compiler asks the
question where there is one, and only there. A step is kept as a run under
`.overlap` that never suspends. It takes no road of its own: measured in a
Release build (2026-10-10, an M-series Mac), an event dispatched to a step
costs some 2 µs end to end - a state's write in it some 66 ns - so even 120
events a second, a drag's, spend a quarter of a millisecond a second.

`RunSlot.underWay` counts the runs of every slot from their start to their
end: what a test waits on for the handlers' work to end, rather than a length
of time, and the tally's `runs` (diagnostics.md).

## A superseded run

A run is superseded by `.cancelPrevious`, and orphaned - superseded the same
way - when its element stops handling the event or leaves the tree. Its task
is cancelled, so `Task.sleep` and whatever else checks cancellation ends it,
and a superseded run ending in `CancellationError` is not reported. An element
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
reading, a post's job, a handler a render queued, the inspector's pace - starts
with no run around it (`libraryTask` clears `HandlerRun.current`), so it belongs
to no run. Started inside a handler, it would inherit
that run and be refused once the run is superseded: a ticker started by a run a
second press cancelled would tick and change nothing.

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
found. Each keeps its runs in the element's `RunSlots`, under a key the element
keeps from one render to the next - its watch's place, its listener's place,
its handler's place - so a change says its `RepeatedEvent` as an event does,
and an element leaving supersedes them all. `.onCreated` runs once; it keeps
runs only so that its element leaving ends them. `.onDestroying` runs as its
element leaves, a farewell, with no runs of its own: it goes to its end.

A subscription to a host event keeps its runs, and `cancel()` supersedes them.
A control the library composes that hears an author's handler inside its own
run - `GalleryView`'s position - starts that handler in a slot of its own, so
the author's word holds there too.
