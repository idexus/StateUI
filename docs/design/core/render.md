# The render

`Renderer` turns the application into the patch a host applies. It holds the
application, knows what changed since the last render, runs the differ, and
hands the result to the host typed, as a `HostRender`.
There is one renderer per process, `Renderer.shared`, because there is one
host per process.

## One renderer

The renderer is `@MainActor`, the UI thread's: the host enters it from that
thread, synchronously, through the typed `HostBoundary` SPI, and a relay's
callback says so once as it enters, with `MainActor.assumeIsolated`.

Everything it keeps - the change bookkeeping, the live reader counts, the act
queue, the completion registry and the counters beside them - is touched on
that thread alone, so none of it stands behind a lock. A task elsewhere
reaches a state by posting to it (state.md#posting) and sends an act by
awaiting it on `MainActor`. A completion is taken out of the registry before
it runs, because what it resumes may book or answer another.

## Three roads

A render takes one of three roads, decided before anything is built:

```text
  describeAll = baseline != generation || nothing rendered yet
  walks       = something rendered, !describeAll, every cause named its state,
                and no cause is among what the root build read

  walks        -> Differ.revisit(current, changed:)    the clean walk
  otherwise    -> build the root, Differ.reconcile(...) a build
  describeAll  -> the patch carries every element in full (a resync)
```

The clean walk skips the application's closure entirely: only the elements
whose recorded reads intersect the changed states are built again, and their
ancestors contribute only the path of patches down to them. It is sound only
when every cause of the render named the state it wrote; a plain
`setNeedsRender()` names nothing and forces a build.

The root build reads the open scenes, whatever the application's `body`
reads, and the application session's styles and motion. Those reads are kept
as `rootReads`; a change to any of them means the application has to be
built again.

## Generations and baseline

A patch means something only against the exact tree it was computed from. The
host quotes back the generation of the last message it applied in full, and
gets a sparse patch only while that matches. Anything else - a first render, a
host that failed half way through a message, a second host showing the same
interface - gets the complete tree.

The complete tree is still reconciled against the tree this side holds, never
against nothing: a resync changes what the message carries, not who anything
is. Keys, handler ids and every `@State` survive it. Reconciling against
nothing would reset every state to its initial value and leave the previous
handler registry reachable from stale controls.

Zero is the host's own "start over" and is never a generation this side
issues; a counter that wraps skips it.

## Taking the changes

The written states and the untracked flag are taken and cleared in one step
before anything is built, and `rendering` is set in the same step. A write
that a build makes while the render runs then stays on the books and asks for
the next render instead of being wiped by this one's clear. The
cost is at most one clean walk that finds nothing; the other direction would
be a control left stale and a handler left waiting on an update nobody draws.

## Handlers in the message

What an element says as it comes into the tree belongs in the message that
brings it. `.onCreated` is where a page gets its title and buttons and a
window its size, and the platform acts on the message that makes the element:
a page presented without its style is presented wrong.

So after the walk, the handlers it found - `.onDestroying` of what left, then
`.onCreated` and `.onChanged` in the order they were reached - run at once,
each up to its first suspension. What they wrote is walked and merged into
the same message, up to `settleLimit` passes. Three passes cover a handler
that writes, a view that arrives with a handler of its own that writes, and
one more; a longer chain is a loop and takes a render per step.

The handlers never run from inside the walk: a handler may write `@State`,
and a write landing mid-walk would be cleared by that walk's bookkeeping.
Handlers found by the last pass, with no pass left to run them, are queued on
`MainActor` rather than started: started at once, their writes would land
after the host's "does anything need rendering" look and wait for the next
event.

## Self-dirtying renders

Nothing else runs while a render does, so a render that ends with the tree
dirty again had a state written by what it built. A streak of `selfDirtyLimit`
such renders is a body that writes the state it reads, which the bookkeeping
would otherwise turn into a render loop; a shorter one ends by itself and is
let be. The error is reported and the pending change dropped once, which ends
the loop. The check runs before the settle passes, so a handler's write is
never taken for a body's.

## Starting a handler

Every handler runs on `MainActor`, inside a task, which gives it somewhere to
suspend. There are three ways in, one path each:

```text
  start(handler)   an event the host dispatched: the payload is read NOW,
                   then begin(...)
  run(handler)     a handler a render's walk found, run in a settle pass
  queue(handler)   a handler found with no settle pass left: Task on MainActor,
                   a later turn of the UI thread
```

`begin` uses `Task.immediate`, which starts the task on the calling thread -
the host's UI thread, which is `MainActor`'s - so a handler with no `await`
finishes before the dispatch returns and the host renders what it wrote in
the same turn. A dispatch runs that handler and nothing else: a job already
waiting on the UI thread's queue runs when the host drains it, at its turn -
the same point on every platform, whichever executor `MainActor` is.

`dispatch` answers whether a handler was found, not whether it finished. An
unknown id is an event for an element that has already left the tree, or an
act already answered; ignoring it is correct.

## The event and reply buffers

An event's payload reaches its handler through `EventBuffer`, and an act's
outcome reaches its continuation through `ReplyBuffer`. A side channel keeps
`HostBoundary.dispatch` to one id and one payload instead of a variant per
event shape. `start` reads the payload before the task begins, so a handler
that suspends keeps the payload it started with. The two buffers stay apart
because an outcome is values or a failure and an event is only values.

## A new application

Registering an application starts a new tree: the previous tree is forgotten
(handlers, engines, root reads), the application session is reset, one scene
waits for the platform's first window, and the next render describes the
whole of the new application - every element arriving, which is what
`.onCreated` is told.

The application itself is made at its first need - the first render, or the
host reading the keys it keeps (`persistentKeys`) - never as it registers: a
head registers it before the host starts, and what its initializer reads of
the environment - the device's form factor a style sheet is chosen by - is
only told once the host has started. Every host tells the environment
before it reads the kept keys and before its first render. The
application's own `@State` properties are named by reflection once, as it is
made, because the application is never walked like a view.

Until an application registers, the tree is an application with one scene,
one window and a page holding a label, in the shape a real one produces, so a
host has one thing to read.
