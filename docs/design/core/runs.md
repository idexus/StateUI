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
`.overlap` that never suspends.

## A superseded run

A run is superseded by `.cancelPrevious`, and orphaned - superseded the same
way - when its element stops handling the event or leaves the tree. Its task
is cancelled, so `Task.sleep` and whatever else checks cancellation ends it,
and a superseded run ending in `CancellationError` is not reported.

From then on it changes nothing. Every write of a state, every part of a
journey (`move`, `stop`, `snap`, its value, velocity and law), every post and
every act made by the run, or by a task under it, is refused and said once; an
act it awaits fails as `CancellationError`. A post's job runs as the run that
posted it, so a post waiting when its run is superseded is refused too.

The run is read through a task-local, `HandlerRun.current`, which the tasks
under a run inherit. A write reads an atomic count of the superseded runs still
under way first, and the task-local only while that count is not nought - a
nanosecond a write in the ordinary case.

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
